--!strict
--[[
	SyncService
	Replicates a read-only snapshot of a player's state to THAT player only.
	Mutations call MarkDirty(); snapshots are coalesced and sent once per frame.
	Notifications carry a locale key + args; the client translates them.
	Also maintains server-owned leaderstats for the player list.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)
local Types = require(Shared.Types)
local Valuation = require(Shared.Valuation)
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)
local FriendService = require(script.Parent.FriendService)
local SocialService = require(script.Parent.SocialService)
local GamePassService = require(script.Parent.GamePassService)
local ProgressViews = require(script.Parent.ProgressViews)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)

local SyncService = {}

local dirty: { [Player]: boolean } = {}
local pendingInstantRepair: { [Player]: string } = {}

local function buildSnapshot(player: Player, data: Types.PlayerData): Types.Snapshot
	local multiplier = Rules.MoneyMultiplier(player, data)
	local views: { Types.ItemView } = {}
	for _, item in data.Inventory do
		local template = Items.Get(item.TemplateId)
		table.insert(views, {
			Id = item.Id,
			TemplateId = item.TemplateId,
			Icon = if template then template.Icon else "?",
			Rarity = item.Rarity,
			State = item.State,
			Shiny = item.Shiny,
			RepairStartedAt = item.RepairStartedAt,
			RepairEndsAt = item.RepairEndsAt,
			ScrubSeconds = item.ScrubSeconds,
			SellValue = Valuation.SellValue(item, multiplier),
			CleanValue = math.floor(Valuation.CleanValue(item) * multiplier),
			AcquiredAt = item.AcquiredAt,
		})
	end
	table.sort(views, function(a, b)
		if a.AcquiredAt == b.AcquiredAt then
			return a.Id < b.Id
		end
		return a.AcquiredAt > b.AcquiredAt
	end)

	local level, xpIn, xpNeeded = Progression.FromTotal(data.XP)
	local today = ProgressViews.Today()
	local rebirthLevel, rebirthCash = Rules.RebirthRequirement(data)
	local pets: { Types.PetView } = {}
	for _, pet in data.Pets do
		table.insert(pets, {
			Id = pet.Id,
			PetId = pet.PetId,
			Equipped = pet.Equipped,
			Stars = pet.Stars,
			Level = pet.Level,
			XP = pet.XP,
		})
	end
	table.sort(pets, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		if a.PetId ~= b.PetId then
			return a.PetId < b.PetId
		end
		return a.Id < b.Id
	end)

	return {
		Cash = data.Cash,
		LifetimeEarned = data.LifetimeEarned,
		Level = level,
		XPInLevel = xpIn,
		XPNeeded = xpNeeded,
		Items = views,
		Capacity = Rules.Capacity(player, data),
		RepairSlots = Rules.RepairSlots(player, data),
		ActiveRepairs = Rules.ActiveRepairs(data),
		InstantRepairTokens = data.InstantRepairTokens,
		BoostEndsAt = data.BoostEndsAt,
		MoneyMultiplier = multiplier,
		Passes = {
			VIPAutoCleaner = GamePassService.Has(player, "VIPAutoCleaner"),
			ExtraCapacity = GamePassService.Has(player, "ExtraCapacity"),
		},
		PendingInstantRepair = pendingInstantRepair[player],
		Quests = ProgressViews.Quests(data),
		QuestsResetAt = (today + 1) * 86400,
		Daily = ProgressViews.Daily(data),
		Collection = data.Collection,
		ShinyCollection = data.ShinyCollection,
		CollectionClaims = data.CollectionClaims,
		TutorialStep = data.TutorialStep,
		Settings = data.Settings,
		Rebirths = data.Rebirths,
		RebirthLevel = rebirthLevel,
		RebirthCash = rebirthCash,
		RebirthBonus = Rules.RebirthBonus(data),
		FriendsBonus = FriendService.Bonus(player),
		Achievements = data.Achievements,
		AchievementProgress = ProgressViews.AchievementProgress(data),
		EquippedTitle = data.EquippedTitle,
		NextSpinAt = data.LastSpinAt + Config.Wheel.CooldownSeconds,
		Pets = pets,
		PetBonuses = {
			Money = Rules.PetBonus(data, "Money"),
			Repair = Rules.PetBonus(data, "Repair"),
			XP = Rules.PetBonus(data, "XP"),
			Luck = Rules.PetBonus(data, "Luck"),
		},
		ActiveEvents = Events.ActiveList(),
		FreeBoxAvailable = Config.FreeDailyBox.Enabled and data.LastFreeBoxDay ~= today,
		Weekly = ProgressViews.Weekly(data),
		Request = data.Request,
		Upgrades = data.Upgrades,
		SocialBonus = SocialService.Bonus(player),
		InGroup = SocialService.InGroup(player),
		GroupEnabled = SocialService.GroupEnabled(),
		IsPremium = SocialService.IsPremium(player),
		ServerTime = os.time(),
	}
end

local function ensureValue(folder: Instance, name: string): IntValue
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = folder
	return value
end

local function updateLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end
	local folder = leaderstats :: Instance
	ensureValue(folder, "Level").Value = Rules.Level(data)
	ensureValue(folder, "Cash").Value = math.floor(math.min(data.Cash, 2 ^ 53))
	ensureValue(folder, "Flips").Value = data.Stats.ItemsSold

	-- Public, server-owned attributes for the overhead name tags (localized on each client).
	player:SetAttribute("Level", Rules.Level(data))
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Title", data.EquippedTitle)
	local equipped = {}
	for _, pet in data.Pets do
		if pet.Equipped then
			table.insert(equipped, pet.PetId .. ":" .. tostring(pet.Stars))
		end
	end
	table.sort(equipped)
	player:SetAttribute("Pets", table.concat(equipped, ","))
end

local function flush()
	if next(dirty) == nil then
		return
	end
	local remote = Net.Get("StateSync")
	for player in dirty do
		dirty[player] = nil
		local profile = DataService.GetProfile(player)
		if profile then
			remote:FireClient(player, buildSnapshot(player, profile.Data))
			updateLeaderstats(player, profile.Data)
		end
	end
end

function SyncService.MarkDirty(player: Player)
	dirty[player] = true
end

-- kind + locale key + string args (see Shared/Locale for special "@" args).
function SyncService.Notify(player: Player, kind: Types.NotifyKind, key: string, args: { string }?)
	Net.Get("Notify"):FireClient(player, kind, key, args or {})
end

-- Same notification to everyone except `except` (e.g. "X found a Legendary!").
function SyncService.Broadcast(except: Player?, kind: Types.NotifyKind, key: string, args: { string }?)
	local remote = Net.Get("Notify")
	for _, other in Players:GetPlayers() do
		if other ~= except then
			remote:FireClient(other, kind, key, args or {})
		end
	end
end

function SyncService.OpenPanel(player: Player, panel: string)
	Net.Get("OpenPanel"):FireClient(player, panel)
end

function SyncService.SetPendingInstantRepair(player: Player, itemId: string?)
	pendingInstantRepair[player] = itemId
	dirty[player] = true
end

function SyncService.GetPendingInstantRepair(player: Player): string?
	return pendingInstantRepair[player]
end

function SyncService.Start()
	RunService.Heartbeat:Connect(flush)
	RemoteGuard.Bind("RequestSync", { RatePerSecond = 0.5, Burst = 3, Args = {} }, function(player: Player)
		SyncService.MarkDirty(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		SyncService.MarkDirty(player)
	end)
	GamePassService.Changed:Connect(function(player)
		SyncService.MarkDirty(player)
	end)
	SocialService.Changed:Connect(function(player)
		SyncService.MarkDirty(player)
	end)
	local lastFriendBonus: { [Player]: number } = {}
	FriendService.Changed:Connect(function(player)
		local bonus = FriendService.Bonus(player)
		if bonus > (lastFriendBonus[player] or 0) and player.Parent == Players then
			SyncService.Notify(player, "success", "N_FriendBonus", { tostring(math.floor(bonus * 100 + 0.5)) })
		end
		lastFriendBonus[player] = if player.Parent == Players then bonus else nil
		SyncService.MarkDirty(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		pendingInstantRepair[player] = nil
	end)
end

return SyncService
