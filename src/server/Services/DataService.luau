--!strict
--[[
	DataService
	Session-locked player persistence (same core guarantees as ProfileService,
	implemented in-house so the project has zero external dependencies).

	GUARANTEES
	1. Session lock: a profile can be ACTIVE in at most one server. Loading
	   takes the lock atomically inside UpdateAsync; a server that is not the
	   lock owner can never write the record (its save transform cancels).
	2. No cross-server duplication: if a server discovers it lost the lock
	   (e.g. it was considered dead and another server took over), it marks the
	   profile inactive, stops all mutations and kicks the player.
	3. No partial writes: data is deep-copied and validated BEFORE it is
	   written. A record containing NaN/inf/negative cash or malformed items is
	   never persisted.
	4. Serialized saves: a profile never has two UpdateAsync calls in flight.
	   SaveNow() always persists a snapshot taken AFTER it was called, which
	   is what ProcessReceipt relies on.
	5. Release on leave / shutdown: PlayerRemoving and BindToClose flush the
	   final state and clear the lock so the player can join elsewhere at once.

	Stored record shape:
	{
		Data = PlayerData,
		Meta = {
			ActiveSession = { SessionId, JobId, PlaceId, LockedAt }?,
			CreatedAt, LastSavedAt, SaveCount,
		},
	}
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Pets = require(Shared.Pets)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local MockDataStore = require(script.Parent.MockDataStore)

local SCHEMA_VERSION = 4

export type Profile = {
	Player: Player,
	UserId: number,
	Key: string,
	SessionId: string,
	Data: Types.PlayerData,
	Active: boolean, -- true while gameplay may mutate Data
	Releasing: boolean,
	Released: boolean,
	LockLost: boolean,
	Saving: boolean,
	LastSavedAt: number,
}

type LoadStatus = "ok" | "locked" | "corrupt" | "error"
type SaveStatus = "ok" | "lost" | "error"

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>
DataService.ProfileReleasing = Signal.new() :: Signal.Signal<Player, Profile>

local store: any = nil
local usingMock = false
local shuttingDown = false

local profiles: { [Player]: Profile } = {}
local loadingPlayers: { [Player]: boolean } = {}
local removedPlayers: { [Player]: boolean } = {}
local releasingUsers: { [number]: number } = {}
local loadingCount = 0

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function log(...: any)
	if Config.Debug.VerboseLogging then
		print("[DataService]", ...)
	end
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return (copy :: any) :: T
end

local function isFiniteNumber(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) ~= math.huge
end

local function readNumber(value: any, default: number, min: number, max: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(value, min, max)
end

local function newData(): Types.PlayerData
	return {
		SchemaVersion = SCHEMA_VERSION,
		Cash = Config.Economy.StartingCash,
		LifetimeEarned = 0,
		XP = 0,
		Inventory = {},
		InstantRepairTokens = 0,
		BoostEndsAt = 0,
		PurchaseHistory = {},
		Collection = {},
		ShinyCollection = {},
		CollectionClaims = {},
		Quests = { Day = -1, Entries = {} },
		Daily = { Streak = 0, LastClaimDay = -10 },
		TutorialStep = 1,
		Settings = { Sound = true, Music = true, Language = "auto" },
		Rebirths = 0,
		Achievements = {},
		EquippedTitle = "",
		RedeemedCodes = {},
		LastSpinAt = 0,
		Pets = {},
		Stats = {
			CratesOpened = 0,
			ItemsSold = 0,
			ItemsRepaired = 0,
			RobuxPurchases = 0,
			ShiniesFound = 0,
			LegendariesFound = 0,
			PetsHatched = 0,
		},
		Moderation = { TotalFlags = 0, LastFlagAt = 0, LastFlagReason = "" },
	}
end

local VALID_STATES = { Dirty = true, Repairing = true, Clean = true }

local function sanitizeItem(id: any, raw: any): Types.ItemRecord?
	if type(id) ~= "string" or type(raw) ~= "table" or raw.Id ~= id then
		return nil
	end
	local template = Items.Get(raw.TemplateId)
	if not template then
		return nil
	end
	local state = if VALID_STATES[raw.State] then raw.State else "Dirty"
	local item: Types.ItemRecord = {
		Id = id,
		TemplateId = template.Id,
		Rarity = template.Rarity, -- always re-derived from the catalog
		State = state,
		Quality = readNumber(raw.Quality, 1, Config.QualityRange.Min, Config.QualityRange.Max),
		Shiny = raw.Shiny == true,
		AcquiredAt = readNumber(raw.AcquiredAt, os.time(), 0, math.huge),
		RepairStartedAt = nil,
		RepairEndsAt = nil,
		ScrubSeconds = readNumber(raw.ScrubSeconds, 0, 0, 1e6),
	}
	if state == "Repairing" then
		if isFiniteNumber(raw.RepairEndsAt) and isFiniteNumber(raw.RepairStartedAt) then
			item.RepairStartedAt = raw.RepairStartedAt
			item.RepairEndsAt = raw.RepairEndsAt
		else
			item.State = "Dirty"
		end
	end
	return item
end

-- Turns whatever came out of the DataStore into a well-formed PlayerData.
-- Unknown/malformed fields are dropped, missing ones get defaults.
local function sanitize(raw: any): Types.PlayerData
	local data = newData()
	if type(raw) ~= "table" then
		return data
	end

	data.Cash = readNumber(raw.Cash, Config.Economy.StartingCash, 0, Config.Economy.MaxCash)
	data.LifetimeEarned = readNumber(raw.LifetimeEarned, 0, 0, math.huge)
	data.InstantRepairTokens = math.floor(readNumber(raw.InstantRepairTokens, 0, 0, 1e6))
	data.BoostEndsAt = readNumber(raw.BoostEndsAt, 0, 0, math.huge)

	if type(raw.Inventory) == "table" then
		for id, rawItem in raw.Inventory do
			local item = sanitizeItem(id, rawItem)
			if item then
				data.Inventory[item.Id] = item
			end
		end
	end

	data.XP = readNumber(raw.XP, 0, 0, 1e12)

	local function readFlags(source: any, target: { [string]: boolean }, isValidKey: (string) -> boolean)
		if type(source) ~= "table" then
			return
		end
		for key, value in source do
			if type(key) == "string" and value == true and isValidKey(key) then
				target[key] = true
			end
		end
	end
	local function isTemplate(key: string): boolean
		return Items.Get(key) ~= nil
	end
	readFlags(raw.Collection, data.Collection, isTemplate)
	readFlags(raw.ShinyCollection, data.ShinyCollection, isTemplate)
	readFlags(raw.CollectionClaims, data.CollectionClaims, Items.IsRarity)

	-- Older saves (schema 1): every item already owned counts as discovered.
	for _, item in data.Inventory do
		data.Collection[item.TemplateId] = true
		if item.Shiny then
			data.ShinyCollection[item.TemplateId] = true
		end
	end

	if type(raw.Quests) == "table" and type(raw.Quests.Entries) == "table" then
		data.Quests.Day = readNumber(raw.Quests.Day, -1, -1, math.huge)
		for _, entry in ipairs(raw.Quests.Entries) do
			if type(entry) == "table" and type(entry.Id) == "string" then
				table.insert(data.Quests.Entries, {
					Id = string.sub(entry.Id, 1, 40),
					Progress = readNumber(entry.Progress, 0, 0, 1e12),
					Claimed = entry.Claimed == true,
				})
			end
		end
	end

	if type(raw.Daily) == "table" then
		data.Daily.Streak = math.floor(readNumber(raw.Daily.Streak, 0, 0, #Config.DailyRewards))
		data.Daily.LastClaimDay = math.floor(readNumber(raw.Daily.LastClaimDay, -10, -10, math.huge))
	end

	-- Existing players from schema 1 skip the tutorial.
	local defaultStep = if type(raw.SchemaVersion) ~= "number" or raw.SchemaVersion < 2 then Config.Tutorial.DoneStep else 1
	data.TutorialStep = math.floor(readNumber(raw.TutorialStep, defaultStep, 1, Config.Tutorial.DoneStep))

	if type(raw.Settings) == "table" then
		data.Settings.Sound = raw.Settings.Sound ~= false
		data.Settings.Music = raw.Settings.Music ~= false
		local language = raw.Settings.Language
		if language == "auto" or table.find(Config.Languages, language) then
			data.Settings.Language = language
		end
	end

	data.Rebirths = math.floor(readNumber(raw.Rebirths, 0, 0, Config.Rebirth.MaxRebirths))
	data.LastSpinAt = readNumber(raw.LastSpinAt, 0, 0, math.huge)
	local achievementIds: { [string]: boolean } = {}
	for _, def in Config.Achievements do
		achievementIds[def.Id] = true
	end
	readFlags(raw.Achievements, data.Achievements, function(key: string): boolean
		return achievementIds[key] == true
	end)
	if type(raw.EquippedTitle) == "string" and data.Achievements[raw.EquippedTitle] then
		data.EquippedTitle = raw.EquippedTitle
	end
	readFlags(raw.RedeemedCodes, data.RedeemedCodes, function(key: string): boolean
		return #key <= 24 -- keep history even for codes that were later removed
	end)

	if type(raw.Pets) == "table" then
		local equipped = 0
		for uid, pet in raw.Pets do
			if
				type(uid) == "string"
				and type(pet) == "table"
				and pet.Id == uid
				and type(pet.PetId) == "string"
				and Pets.Get(pet.PetId) ~= nil
			then
				local wantsEquip = pet.Equipped == true and equipped < Config.Pets.MaxEquipped
				if wantsEquip then
					equipped += 1
				end
				data.Pets[uid] = {
					Id = uid,
					PetId = pet.PetId,
					Equipped = wantsEquip,
					Stars = math.floor(readNumber(pet.Stars, 0, 0, Config.Pets.MaxStars)),
				}
			end
		end
	end

	if type(raw.PurchaseHistory) == "table" then
		for _, purchaseId in ipairs(raw.PurchaseHistory) do
			if type(purchaseId) == "string" then
				table.insert(data.PurchaseHistory, purchaseId)
			end
		end
		while #data.PurchaseHistory > Config.Products.PurchaseHistoryLimit do
			table.remove(data.PurchaseHistory, 1)
		end
	end

	if type(raw.Stats) == "table" then
		data.Stats.CratesOpened = readNumber(raw.Stats.CratesOpened, 0, 0, math.huge)
		data.Stats.ItemsSold = readNumber(raw.Stats.ItemsSold, 0, 0, math.huge)
		data.Stats.ItemsRepaired = readNumber(raw.Stats.ItemsRepaired, 0, 0, math.huge)
		data.Stats.RobuxPurchases = readNumber(raw.Stats.RobuxPurchases, 0, 0, math.huge)
		data.Stats.ShiniesFound = readNumber(raw.Stats.ShiniesFound, 0, 0, math.huge)
		data.Stats.LegendariesFound = readNumber(raw.Stats.LegendariesFound, 0, 0, math.huge)
		data.Stats.PetsHatched = readNumber(raw.Stats.PetsHatched, 0, 0, math.huge)
	end

	if type(raw.Moderation) == "table" then
		data.Moderation.TotalFlags = readNumber(raw.Moderation.TotalFlags, 0, 0, math.huge)
		data.Moderation.LastFlagAt = readNumber(raw.Moderation.LastFlagAt, 0, 0, math.huge)
		if type(raw.Moderation.LastFlagReason) == "string" then
			data.Moderation.LastFlagReason = string.sub(raw.Moderation.LastFlagReason, 1, 100)
		end
	end

	-- Future schema migrations go here, keyed on raw.SchemaVersion.
	data.SchemaVersion = SCHEMA_VERSION
	return data
end

-- Final gate before anything is written. Refuses to persist corrupt state.
local function validateForSave(data: Types.PlayerData): (boolean, string?)
	if not isFiniteNumber(data.Cash) or data.Cash < 0 then
		return false, "invalid cash"
	end
	if not isFiniteNumber(data.LifetimeEarned) or data.LifetimeEarned < 0 then
		return false, "invalid lifetime earned"
	end
	if not isFiniteNumber(data.InstantRepairTokens) or data.InstantRepairTokens < 0 then
		return false, "invalid tokens"
	end
	if not isFiniteNumber(data.BoostEndsAt) then
		return false, "invalid boost"
	end
	if not isFiniteNumber(data.XP) or data.XP < 0 then
		return false, "invalid xp"
	end
	for id, item in data.Inventory do
		if type(id) ~= "string" or item.Id ~= id or Items.Get(item.TemplateId) == nil then
			return false, "invalid item " .. tostring(id)
		end
		if not VALID_STATES[item.State] or not isFiniteNumber(item.Quality) or not isFiniteNumber(item.ScrubSeconds) then
			return false, "invalid item fields " .. id
		end
	end
	return true, nil
end

local function keyFor(userId: number): string
	return Config.Data.KeyPrefix .. tostring(userId)
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	if usingMock then
		return
	end
	local deadline = os.clock() + 10
	while DataStoreService:GetRequestBudgetForRequestType(requestType) <= 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end

local function isInGame(player: Player): boolean
	return not removedPlayers[player] and player:IsDescendantOf(Players)
end

------------------------------------------------------------------------
-- Store access
------------------------------------------------------------------------

local function resolveStore(): any
	local ok, realStore = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)

	if RunService:IsStudio() and Config.Data.UseMockStoreInStudioIfUnavailable then
		local works = ok and pcall(function()
			(realStore :: any):GetAsync("__studio_ping")
		end)
		if not works then
			warn(
				"[DataService] Studio has no DataStore access (Game Settings > Security > "
					.. "Enable Studio Access to API Services). Using in-memory MockDataStore; data will NOT persist."
			)
			usingMock = true
			return MockDataStore.new()
		end
	end

	if not ok then
		error("[DataService] Could not open DataStore: " .. tostring(realStore))
	end
	return realStore
end

local function loadRecord(key: string, sessionId: string): (LoadStatus, any)
	local status: LoadStatus = "error"
	local loaded: any = nil

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any): any
			status = "error"
			loaded = nil
			local now = os.time()

			local record: any
			if old == nil then
				record = {
					Data = newData(),
					Meta = { CreatedAt = now, LastSavedAt = 0, SaveCount = 0 },
				}
			elseif type(old) ~= "table" or type(old.Meta) ~= "table" then
				-- Never overwrite something we do not understand; keep it for manual recovery.
				status = "corrupt"
				return nil
			else
				record = old
			end

			local lock = record.Meta.ActiveSession
			local lockIsLive = type(lock) == "table"
				and type(lock.SessionId) == "string"
				and lock.SessionId ~= sessionId -- our own lock from a retried request is fine
				and isFiniteNumber(lock.LockedAt)
				and now - lock.LockedAt < Config.Data.LockStaleSeconds
			if lockIsLive then
				status = "locked"
				return nil
			end

			record.Meta.ActiveSession = {
				SessionId = sessionId,
				JobId = game.JobId,
				PlaceId = game.PlaceId,
				LockedAt = now,
			}
			status = "ok"
			loaded = record.Data
			return record
		end)
	end)

	if not ok then
		warn("[DataService] Load request failed for", key, err)
		return "error", nil
	end
	return status, loaded
end

local function writeRecord(profile: Profile, release: boolean): SaveStatus
	local payload = deepCopy(profile.Data)
	local valid, reason = validateForSave(payload)
	if not valid then
		warn("[DataService] Refusing to save corrupt data for", profile.Key, reason)
		return "error"
	end

	local status: SaveStatus = "error"
	local ok, err = pcall(function()
		store:UpdateAsync(profile.Key, function(old: any): any
			status = "error"
			if type(old) ~= "table" or type(old.Meta) ~= "table" then
				status = "lost"
				return nil
			end
			local lock = old.Meta.ActiveSession
			if type(lock) ~= "table" or lock.SessionId ~= profile.SessionId then
				-- Another server owns this record now. Abort without writing.
				status = "lost"
				return nil
			end

			local now = os.time()
			old.Data = payload
			old.Meta.LastSavedAt = now
			old.Meta.SaveCount = (if isFiniteNumber(old.Meta.SaveCount) then old.Meta.SaveCount else 0) + 1
			if release then
				old.Meta.ActiveSession = nil
			else
				lock.LockedAt = now -- heartbeat: keeps the lock from going stale
			end
			status = "ok"
			return old
		end)
	end)

	if not ok then
		warn("[DataService] Save request failed for", profile.Key, err)
		return "error"
	end
	return status
end

------------------------------------------------------------------------
-- Profile lifecycle
------------------------------------------------------------------------

local function onLockLost(profile: Profile)
	if profile.LockLost then
		return
	end
	profile.LockLost = true
	profile.Active = false
	warn("[DataService] Session lock lost for", profile.Key, "- profile deactivated")
	if profiles[profile.Player] == profile then
		profiles[profile.Player] = nil
	end
	if isInGame(profile.Player) then
		profile.Player:Kick("Your data was loaded on another server. Please rejoin.")
	end
end

-- Serialized save. Returns true only if a snapshot taken after this call was committed.
local function saveProfile(profile: Profile, release: boolean): boolean
	while profile.Saving do
		task.wait()
	end
	if profile.Released or profile.LockLost then
		return false
	end

	profile.Saving = true
	local result: SaveStatus = "error"
	for attempt = 1, Config.Data.SaveRetryCount do
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		result = writeRecord(profile, release)
		if result ~= "error" then
			break
		end
		if attempt < Config.Data.SaveRetryCount then
			task.wait(2 ^ attempt)
		end
	end
	profile.Saving = false

	if result == "ok" then
		profile.LastSavedAt = os.clock()
		if release then
			profile.Released = true
		end
		log("Saved", profile.Key, release and "(release)" or "")
		return true
	elseif result == "lost" then
		onLockLost(profile)
	end
	return false
end

local function releaseProfile(profile: Profile)
	if profile.Releasing or profile.Released or profile.LockLost then
		return
	end
	profile.Releasing = true
	profile.Active = false -- from here on, gameplay code must not touch Data

	local userId = profile.UserId
	releasingUsers[userId] = (releasingUsers[userId] or 0) + 1
	DataService.ProfileReleasing:Fire(profile.Player, profile)

	local ok = saveProfile(profile, true)
	if not ok then
		warn("[DataService] Final save failed for", profile.Key, "- lock will expire after LockStaleSeconds")
	end

	if profiles[profile.Player] == profile then
		profiles[profile.Player] = nil
	end
	local remaining = (releasingUsers[userId] or 1) - 1
	releasingUsers[userId] = if remaining > 0 then remaining else nil
end

local function onPlayerAdded(player: Player)
	if loadingPlayers[player] or profiles[player] then
		return
	end
	loadingPlayers[player] = true
	loadingCount += 1

	-- Same-server rejoin: wait for our own release of the previous session.
	local waitStart = os.clock()
	while releasingUsers[player.UserId] and os.clock() - waitStart < 30 do
		task.wait(0.25)
	end

	local key = keyFor(player.UserId)
	local sessionId = HttpService:GenerateGUID(false)
	local status: LoadStatus = "error"
	local raw: any = nil

	for attempt = 1, Config.Data.LoadRetryCount do
		if not isInGame(player) and attempt > 1 then
			break
		end
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		status, raw = loadRecord(key, sessionId)
		if status == "ok" or status == "corrupt" then
			break
		end
		log("Load attempt", attempt, "for", key, "->", status)
		task.wait(Config.Data.LoadRetryDelaySeconds)
	end

	loadingPlayers[player] = nil
	loadingCount -= 1

	if status ~= "ok" then
		if isInGame(player) then
			local message = if status == "locked"
				then "Your data is still saving on another server. Please rejoin in a minute."
				elseif status == "corrupt" then "Your data could not be read. Please contact support."
				else "Roblox data services are unavailable right now. Please rejoin shortly."
			player:Kick(message)
		end
		return
	end

	local profile: Profile = {
		Player = player,
		UserId = player.UserId,
		Key = key,
		SessionId = sessionId,
		Data = sanitize(raw),
		Active = true,
		Releasing = false,
		Released = false,
		LockLost = false,
		Saving = false,
		LastSavedAt = os.clock(),
	}
	profiles[player] = profile

	if not isInGame(player) or shuttingDown then
		releaseProfile(profile)
		return
	end

	log("Loaded", key)
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	removedPlayers[player] = true
	local profile = profiles[player]
	if profile then
		releaseProfile(profile)
	end
	-- Allow the Player object to be garbage collected later.
	task.delay(60, function()
		removedPlayers[player] = nil
	end)
end

local function autosaveLoop()
	while true do
		task.wait(Config.Data.AutoSaveSeconds)
		local list: { Profile } = {}
		for _, profile in profiles do
			if profile.Active then
				table.insert(list, profile)
			end
		end
		-- Spread requests across half the interval to stay inside DataStore budgets.
		local spacing = (Config.Data.AutoSaveSeconds * 0.5) / math.max(#list, 1)
		for index, profile in list do
			task.delay((index - 1) * spacing, function()
				if profile.Active then
					saveProfile(profile, false)
				end
			end)
		end
	end
end

local function onClose()
	shuttingDown = true
	for _, profile in profiles do
		task.spawn(releaseProfile, profile)
	end
	local deadline = os.clock() + 25
	while (next(profiles) ~= nil or loadingCount > 0) and os.clock() < deadline do
		task.wait(0.1)
	end
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- Returns the profile only while it is safe to mutate.
function DataService.GetProfile(player: Player): Profile?
	local profile = profiles[player]
	if profile and profile.Active then
		return profile
	end
	return nil
end

function DataService.WaitForProfile(player: Player, timeoutSeconds: number): Profile?
	local deadline = os.clock() + timeoutSeconds
	while os.clock() < deadline do
		local profile = DataService.GetProfile(player)
		if profile then
			return profile
		end
		if not isInGame(player) then
			return nil
		end
		task.wait(0.1)
	end
	return DataService.GetProfile(player)
end

-- Persists the current state now. Yields. Used by ProcessReceipt.
function DataService.SaveNow(profile: Profile): boolean
	if not profile.Active then
		return false
	end
	return saveProfile(profile, false)
end

function DataService.IsUsingMock(): boolean
	return usingMock
end

function DataService.Start()
	store = resolveStore()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(onClose)
	task.spawn(autosaveLoop)
end

return DataService
