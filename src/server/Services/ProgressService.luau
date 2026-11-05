--!strict
--[[
	ProgressService
	Levels/XP, daily quests, 7-day login gift, collection book, tutorial and
	player settings. Everything is server-authoritative:

	- Progress only moves when the SERVER emits an event (Record) from inside
	  an already-validated action (crate bought, repair finished, item sold).
	  There is no remote that reports progress.
	- Claims re-check eligibility on the server and mark the claim in the same
	  non-yielding block that grants the reward, so a reward can never be
	  claimed twice (double-click, lag, two remotes in one frame).
	- Days are UTC days from os.time(); the client clock is never used.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Progression = require(Shared.Progression)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local ProgressViews = require(script.Parent.ProgressViews)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)
local SyncService = require(script.Parent.SyncService)

local ProgressService = {}

local rng = Random.new()
local checkingAchievements: { [Player]: boolean } = {}

------------------------------------------------------------------------
-- XP & rewards
------------------------------------------------------------------------

local checkAchievements: (Player, Types.PlayerData) -> ()

function ProgressService.AddXP(player: Player, data: Types.PlayerData, amount: number)
	if amount <= 0 then
		return
	end
	local before = Progression.LevelFromTotal(data.XP)
	amount *= 1 + Rules.PetBonus(data, "XP")
	data.XP = math.min(1e12, data.XP + math.floor(amount))
	local after = Progression.LevelFromTotal(data.XP)
	for level = before + 1, after do
		local bonus = level * Config.Progression.LevelUpCashPerLevel
		Rules.AddCash(data, bonus, false)
		SyncService.Notify(player, "levelup", "N_LevelUp", { tostring(level), Format.Cash(bonus) })
	end
	if after > before then
		checkAchievements(player, data)
	end
	SyncService.MarkDirty(player)
end

-- Grants a Config reward table. Synchronous; never yields.
function ProgressService.GrantReward(player: Player, data: Types.PlayerData, reward: Types.Reward)
	if (reward.Cash or 0) > 0 then
		Rules.AddCash(data, reward.Cash :: number, false)
	end
	if (reward.Tokens or 0) > 0 then
		data.InstantRepairTokens += math.floor(reward.Tokens :: number)
	end
	if (reward.BoostMinutes or 0) > 0 then
		Rules.ExtendBoost(data, (reward.BoostMinutes :: number) * 60)
	end
	if (reward.XP or 0) > 0 then
		ProgressService.AddXP(player, data, reward.XP :: number)
	end
	SyncService.MarkDirty(player)
end

------------------------------------------------------------------------
-- Achievements (automatic unlock + reward + title)
------------------------------------------------------------------------

checkAchievements = function(player: Player, data: Types.PlayerData)
	if checkingAchievements[player] then
		return -- a reward is being granted inside a check; the outer loop continues
	end
	checkingAchievements[player] = true
	local unlockedAny = true
	while unlockedAny do
		unlockedAny = false
		for _, def in Config.Achievements do
			if not data.Achievements[def.Id] and ProgressViews.StatValue(data, def.Stat) >= ProgressViews.AchievementGoal(def) then
				unlockedAny = true
				data.Achievements[def.Id] = true
				ProgressService.GrantReward(player, data, def.Reward)
				SyncService.Notify(player, "levelup", "N_Achievement", { "@ach:" .. def.Id, Locale.EncodeReward(def.Reward) })
				if data.EquippedTitle == "" then
					data.EquippedTitle = def.Id -- first title is worn automatically
				end
			end
		end
	end
	checkingAchievements[player] = nil
	SyncService.MarkDirty(player)
end

ProgressService.CheckAchievements = checkAchievements

------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------

-- Rolls today's quests if the day changed. Deterministic per player + day.
function ProgressService.EnsureQuests(player: Player, data: Types.PlayerData): boolean
	local today = ProgressViews.Today()
	local allValid = true
	for _, entry in data.Quests.Entries do
		if not ProgressViews.QuestDef(entry.Id) then
			allValid = false
		end
	end
	if data.Quests.Day == today and allValid then
		return false
	end
	local pool = table.clone(Config.Quests.Pool)
	local questRng = Random.new(player.UserId * 31 + today)
	local entries: { Types.QuestEntry } = {}
	local usedEvents: { [string]: boolean } = {}
	while #entries < Config.Quests.PerDay and #pool > 0 do
		local index = questRng:NextInteger(1, #pool)
		local def = table.remove(pool, index) :: any
		-- Prefer variety: avoid two quests on the same event when possible.
		if not usedEvents[def.Event] or #pool < Config.Quests.PerDay - #entries then
			usedEvents[def.Event] = true
			table.insert(entries, { Id = def.Id, Progress = 0, Claimed = false })
		end
	end
	data.Quests = { Day = today, Entries = entries }
	SyncService.MarkDirty(player)
	return true
end

------------------------------------------------------------------------
-- Tutorial
------------------------------------------------------------------------

local function advanceTutorial(player: Player, data: Types.PlayerData, event: string)
	local step = data.TutorialStep
	local done = Config.Tutorial.DoneStep
	if step >= done then
		return
	end
	local nextStep = step
	if event == "CrateOpened" and step == 1 then
		nextStep = 2
	elseif event == "RepairStarted" and step == 2 then
		nextStep = 3
	elseif event == "ItemRepaired" and step >= 2 and step <= 3 then
		nextStep = 4
	elseif event == "ItemSold" and step >= 2 then
		nextStep = done
	end
	if nextStep == step then
		return
	end
	data.TutorialStep = nextStep
	if nextStep == done then
		local reward = Config.Tutorial.Reward
		ProgressService.GrantReward(player, data, reward)
		SyncService.Notify(player, "levelup", "N_TutorialDone", { Locale.EncodeReward(reward) })
	end
	SyncService.MarkDirty(player)
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

-- Called by other services AFTER a validated action. Synchronous.
function ProgressService.Record(player: Player, data: Types.PlayerData, event: string, amount: number)
	ProgressService.EnsureQuests(player, data)
	for _, entry in data.Quests.Entries do
		local def = ProgressViews.QuestDef(entry.Id)
		if def and def.Event == event and not entry.Claimed and entry.Progress < def.Goal then
			entry.Progress = math.min(def.Goal, entry.Progress + amount)
			if entry.Progress >= def.Goal then
				SyncService.Notify(player, "success", "N_QuestComplete")
			end
		end
	end
	advanceTutorial(player, data, event)
	checkAchievements(player, data)
	SyncService.MarkDirty(player)
end

-- Collection book + shiny tracking for a freshly obtained item.
function ProgressService.Discover(player: Player, data: Types.PlayerData, item: Types.ItemRecord)
	local templateId = item.TemplateId
	local itemTemplate = Items.Get(templateId)
	local isEventItem = itemTemplate ~= nil and itemTemplate.Event ~= nil
	if not data.Collection[templateId] then
		data.Collection[templateId] = true
		SyncService.Notify(player, "info", "N_NewDiscovery", { "@item:" .. templateId })

		local complete = true
		for _, template in Items.GetByRarity(item.Rarity) do
			if not data.Collection[template.Id] then
				complete = false
				break
			end
		end
		if complete and not isEventItem and not data.CollectionClaims[item.Rarity] then
			SyncService.Notify(player, "success", "N_CollectionReady", { "@rarity:" .. item.Rarity })
		end
	end
	if item.Shiny then
		data.ShinyCollection[templateId] = true
		data.Stats.ShiniesFound += 1
		ProgressService.AddXP(player, data, Config.Progression.XP.ShinyBonus)
	end
	if item.Rarity == "Rare" then
		ProgressService.Record(player, data, "FoundRare", 1)
	elseif item.Rarity == "Legendary" then
		data.Stats.LegendariesFound += 1
		ProgressService.Record(player, data, "FoundLegendary", 1)
	end
end

------------------------------------------------------------------------
-- Remote handlers (claims & settings)
------------------------------------------------------------------------

local function onClaimDaily(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local today = ProgressViews.Today()
	if data.Daily.LastClaimDay == today then
		SyncService.Notify(player, "info", "N_DailyAlready")
		return
	end
	local day = ProgressViews.NextDailyDay(data, today)
	local reward = Config.DailyRewards[day]
	-- Atomic: mark claimed, then grant.
	data.Daily.LastClaimDay = today
	data.Daily.Streak = day
	ProgressService.GrantReward(player, data, reward)
	SyncService.Notify(player, "success", "N_RewardClaimed", { Locale.EncodeReward(reward) })
end

local function onClaimQuest(player: Player, index: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	ProgressService.EnsureQuests(player, data)
	local entry = data.Quests.Entries[index]
	if not entry or entry.Claimed then
		return
	end
	local def = ProgressViews.QuestDef(entry.Id)
	if not def or entry.Progress < def.Goal then
		return
	end
	entry.Claimed = true
	ProgressService.GrantReward(player, data, def.Reward)
	SyncService.Notify(player, "success", "N_RewardClaimed", { Locale.EncodeReward(def.Reward) })
end

local function onClaimCollection(player: Player, rarity: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	if data.CollectionClaims[rarity] then
		return
	end
	for _, template in Items.GetByRarity(rarity :: Types.Rarity) do
		if not data.Collection[template.Id] then
			return
		end
	end
	local reward = (Config.Collection.Rewards :: any)[rarity]
	if not reward then
		return
	end
	data.CollectionClaims[rarity] = true
	ProgressService.GrantReward(player, data, reward)
	SyncService.Notify(player, "levelup", "N_RewardClaimed", { Locale.EncodeReward(reward) })
end

local function onSkipTutorial(player: Player)
	local profile = DataService.GetProfile(player)
	if profile and profile.Data.TutorialStep < Config.Tutorial.DoneStep then
		profile.Data.TutorialStep = Config.Tutorial.DoneStep -- skipping gives no reward
		SyncService.MarkDirty(player)
	end
end

local function onSetSetting(player: Player, key: string, value: any)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local settings = profile.Data.Settings
	if (key == "Sound" or key == "Music") and type(value) == "boolean" then
		settings[key] = value
	elseif key == "Language" and (value == "auto" or table.find(Config.Languages, value)) then
		settings.Language = value
	else
		return
	end
	SyncService.MarkDirty(player)
end

local function onRebirth(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	if data.Rebirths >= Config.Rebirth.MaxRebirths then
		return
	end
	local needLevel, needCash = Rules.RebirthRequirement(data)
	if Rules.Level(data) < needLevel or data.Cash < needCash then
		SyncService.Notify(player, "error", "N_RebirthNotReady", { tostring(needLevel), Format.Cash(needCash) })
		return
	end
	-- Atomic: reset progress, grant the permanent bonus.
	data.Cash = Config.Economy.StartingCash
	data.XP = 0
	data.Rebirths += 1
	local bonusPercent = math.floor(Rules.RebirthBonus(data) * 100 + 0.5)
	SyncService.Notify(player, "levelup", "N_Rebirth", { tostring(bonusPercent) })
	checkAchievements(player, data)
	SyncService.MarkDirty(player)
end

local function onSpinWheel(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local now = os.time()
	local readyAt = data.LastSpinAt + Config.Wheel.CooldownSeconds
	if now < readyAt then
		SyncService.Notify(player, "info", "N_WheelWait", { Format.Duration(readyAt - now) })
		return
	end

	local total = 0
	for _, prize in Config.Wheel.Prizes do
		total += prize.Weight
	end
	local roll = rng:NextNumber() * total
	local index = #Config.Wheel.Prizes
	for i, prize in Config.Wheel.Prizes do
		roll -= prize.Weight
		if roll < 0 then
			index = i
			break
		end
	end

	local base = Config.Wheel.Prizes[index].Reward :: any
	local reward: Types.Reward = {
		Cash = if base.Cash then math.floor(base.Cash * (1 + Rules.Level(data) * Config.Wheel.CashLevelScale)) else nil,
		Tokens = base.Tokens,
		BoostMinutes = base.BoostMinutes,
		XP = base.XP,
	}
	-- Atomic: start the cooldown, then grant.
	data.LastSpinAt = now
	ProgressService.GrantReward(player, data, reward)
	SyncService.Notify(player, "wheel", "N_WheelWin", { tostring(index), Locale.EncodeReward(reward) })
end

local function onSetTitle(player: Player, achievementId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	if achievementId == "" or data.Achievements[achievementId] then
		data.EquippedTitle = achievementId
		SyncService.MarkDirty(player)
	end
end

function ProgressService.Start()
	local V = RemoteGuard.Validators
	RemoteGuard.Bind("ClaimDaily", { RatePerSecond = 1, Burst = 3, Args = {} }, onClaimDaily)
	RemoteGuard.Bind("ClaimQuest", {
		RatePerSecond = 2,
		Burst = 4,
		Args = { V.IntRange(1, Config.Quests.PerDay) },
	}, onClaimQuest)
	RemoteGuard.Bind("ClaimCollection", {
		RatePerSecond = 1,
		Burst = 3,
		Args = { V.OneOf(Items.Rarities :: any) },
	}, onClaimCollection)
	RemoteGuard.Bind("SkipTutorial", { RatePerSecond = 0.5, Burst = 2, Args = {} }, onSkipTutorial)
	RemoteGuard.Bind("SetSetting", {
		RatePerSecond = 2,
		Burst = 6,
		Args = { V.OneOf({ "Sound", "Music", "Language" }), V.BooleanOrShortString },
	}, onSetSetting)

	RemoteGuard.Bind("Rebirth", { RatePerSecond = 0.5, Burst = 2, Args = {} }, onRebirth)
	RemoteGuard.Bind("SpinWheel", { RatePerSecond = 0.5, Burst = 2, Args = {} }, onSpinWheel)
	RemoteGuard.Bind("SetTitle", {
		RatePerSecond = 1,
		Burst = 3,
		Args = {
			function(value: unknown): boolean
				return type(value) == "string" and #value <= 40
			end,
		},
	}, onSetTitle)

	DataService.ProfileLoaded:Connect(function(player, profile)
		ProgressService.EnsureQuests(player, profile.Data)
		checkAchievements(player, profile.Data) -- catches stats from older saves
	end)
	Players.PlayerRemoving:Connect(function(player)
		checkingAchievements[player] = nil
	end)

	-- Midnight (UTC) rollover for players who stay online.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local profile = DataService.GetProfile(player)
				if profile then
					ProgressService.EnsureQuests(player, profile.Data)
				end
			end
		end
	end)
end

return ProgressService
