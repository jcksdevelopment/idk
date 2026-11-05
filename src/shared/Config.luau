--!strict
--[[
	Config
	Single source of truth for tunables, Robux product IDs, progression,
	quests, rewards, sounds and station layout.

	>>> INSERT YOUR IDS HERE <<<
	Replace every 0 in GamePasses / DevProducts with the IDs from the Creator
	Dashboard (Monetization -> Passes / Developer Products). An ID of 0 means
	"not configured": the shop shows the item as "Soon" and the server refuses
	to prompt it.
]]

local Config = {}

------------------------------------------------------------------------
-- Robux
------------------------------------------------------------------------

Config.GamePasses = {
	VIPAutoCleaner = 0, -- Game Pass ID: background auto-repair + extra repair slots
	ExtraCapacity = 0, -- Game Pass ID: +20 inventory capacity
}

Config.DevProducts = {
	InstantRepair = 0, -- Developer Product ID: instantly finish one repair
	MoneyBoost2x = 0, -- Developer Product ID: 2x sell money for a limited time
	CashPackSmall = 0, -- Developer Product ID: flat cash bundle
}

-- Kid-friendly monetization: no pressure tactics. Everything sold for Robux
-- can also be earned by playing (quests, daily rewards, collection book).
Config.Monetization = {
	ShowUpsells = false, -- true = small "get more" hints in HUD / inventory
}

-- Display metadata for the cash shop. Titles/descriptions come from Locale.
Config.ShopDisplay = {
	DevProducts = {
		InstantRepair = { Icon = "⚡", Ribbon = "Ribbon_Popular", Order = 1 },
		MoneyBoost2x = { Icon = "💰", Ribbon = "Ribbon_BestValue", Order = 2 },
		CashPackSmall = { Icon = "💵", Ribbon = "", Order = 3 },
	},
	GamePasses = {
		VIPAutoCleaner = { Icon = "🤖", Ribbon = "Ribbon_VIP", Order = 1 },
		ExtraCapacity = { Icon = "🎒", Ribbon = "", Order = 2 },
	},
}

Config.Products = {
	MoneyBoostMultiplier = 2,
	MoneyBoostDurationSeconds = 15 * 60,
	MoneyBoostMaxStackSeconds = 24 * 60 * 60,
	CashPackSmallAmount = 2500,
	PurchaseHistoryLimit = 100,
}

------------------------------------------------------------------------
-- Economy
------------------------------------------------------------------------

Config.Economy = {
	StartingCash = 100,
	DirtySellRatio = 0.35, -- unrepaired items sell for 35% of their clean value
	MaxCash = 1e15,
}

Config.Inventory = {
	BaseCapacity = 10,
	ExtraCapacityBonus = 20,
	-- Free capacity from levelling: +LevelBonusSlots every LevelBonusEvery levels.
	LevelBonusEvery = 5,
	LevelBonusSlots = 2,
	MaxLevelBonus = 20,
}

Config.Repair = {
	BaseSlots = 1,
	VIPExtraSlots = 2,
	SecondsByRarity = { Trash = 8, Rare = 30, Legendary = 90 },
	EarlyToleranceSeconds = 2,
	VIPTickSeconds = 1,
}

-- Scrub mini-game: every tap on a repairing item shaves time off, capped so
-- that auto-clickers gain nothing beyond what a fast kid can do.
Config.Scrub = {
	SecondsPerScrub = 0.5,
	MaxReductionRatio = 0.6, -- at most 60% of the repair can be scrubbed away
	RatePerSecond = 8, -- server ignores taps faster than this (no flag)
}

Config.Shiny = {
	Chance = 0.03, -- 3% of found items are ✨ shiny
	ValueMultiplier = 2.5,
}

-- Rarity weights per crate. JunkBox uses the canonical 70 / 25 / 5 split.
Config.Crates = {
	JunkBox = {
		Icon = "📦",
		Price = 25,
		Order = 1,
		UnlockLevel = 1,
		Weights = { Trash = 70, Rare = 25, Legendary = 5 },
	},
	AntiqueChest = {
		Icon = "🧰",
		Price = 250,
		Order = 2,
		UnlockLevel = 3,
		Weights = { Trash = 40, Rare = 45, Legendary = 15 },
	},
	RoyalTreasure = {
		Icon = "👑",
		Price = 1500,
		Order = 3,
		UnlockLevel = 8,
		Weights = { Trash = 15, Rare = 50, Legendary = 35 },
	},
}

Config.QualityRange = { Min = 0.8, Max = 1.25 }

------------------------------------------------------------------------
-- Progression, quests, rewards
------------------------------------------------------------------------

-- A Reward can contain any of: Cash, Tokens (Instant Repair), BoostMinutes, XP.
Config.Progression = {
	MaxLevel = 100,
	BaseXP = 25, -- XP to go from level 1 -> 2
	XPGrowth = 15, -- each level needs this much more
	LevelUpCashPerLevel = 40, -- reward on level up = level * this
	XP = {
		CrateOpened = 2,
		Repaired = { Trash = 3, Rare = 8, Legendary = 20 },
		Sold = { Trash = 2, Rare = 5, Legendary = 12 },
		ShinyBonus = 10,
	},
}

-- 7-day login calendar; the streak loops after day 7.
Config.DailyRewards = {
	{ Cash = 100 },
	{ Cash = 200 },
	{ Tokens = 1 },
	{ Cash = 400 },
	{ BoostMinutes = 10 },
	{ Cash = 800, Tokens = 1 },
	{ Cash = 1500, Tokens = 2, BoostMinutes = 15 },
}

-- Three quests are picked per player per day (UTC) from this pool.
-- Event names are emitted by the server only.
Config.Quests = {
	PerDay = 3,
	Pool = {
		{ Id = "OpenCrates", Event = "CrateOpened", Goal = 5, Reward = { Cash = 150, XP = 15 } },
		{ Id = "OpenManyCrates", Event = "CrateOpened", Goal = 15, Reward = { Cash = 400, XP = 30 } },
		{ Id = "RepairItems", Event = "ItemRepaired", Goal = 3, Reward = { Cash = 120, XP = 15 } },
		{ Id = "RepairManyItems", Event = "ItemRepaired", Goal = 10, Reward = { Tokens = 1, XP = 40 } },
		{ Id = "SellItems", Event = "ItemSold", Goal = 5, Reward = { Cash = 200, XP = 15 } },
		{ Id = "EarnCash", Event = "CashEarned", Goal = 1000, Reward = { BoostMinutes = 5, XP = 25 } },
		{ Id = "Scrub", Event = "Scrub", Goal = 40, Reward = { Cash = 150, XP = 20 } },
		{ Id = "FindRare", Event = "FoundRare", Goal = 2, Reward = { Cash = 250, XP = 20 } },
		{ Id = "FindLegendary", Event = "FoundLegendary", Goal = 1, Reward = { Tokens = 1, XP = 30 } },
	},
}

-- Collection book: discover every item of a rarity to claim its reward.
Config.Collection = {
	Rewards = {
		Trash = { Cash = 500, Tokens = 1 },
		Rare = { Cash = 3000, Tokens = 3 },
		Legendary = { Cash = 20000, Tokens = 10 },
	},
}

Config.Tutorial = {
	-- Steps: 1 buy a crate, 2 start a repair, 3 finish it, 4 sell it, 5 done.
	DoneStep = 5,
	Reward = { Cash = 150, Tokens = 1 },
}

------------------------------------------------------------------------
-- Audio (client). Replace with your own uploaded audio IDs any time.
-- Built-in rbxasset sounds are used so the game is never silent out of the box.
------------------------------------------------------------------------

Config.Sounds = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35 },
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Reveal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8 },
	Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 },
	Scrub = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.25 },
	LevelUp = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.4 },
	-- Background music: put an audio asset id here (e.g. "rbxassetid://123") or leave empty.
	Music = { Id = "", Volume = 0.25 },
}

------------------------------------------------------------------------
-- World
------------------------------------------------------------------------

Config.Stations = {
	RequireProximity = true,
	InteractRadius = 18,
	ServerLeeway = 6,
	Bazaar = { Position = Vector3.new(-26, 3, -22), Color = Color3.fromRGB(255, 140, 40) },
	Workbench = { Position = Vector3.new(0, 3, -32), Color = Color3.fromRGB(60, 160, 255) },
	SellCounter = { Position = Vector3.new(26, 3, -22), Color = Color3.fromRGB(70, 220, 120) },
}

------------------------------------------------------------------------
-- Persistence & security
------------------------------------------------------------------------

Config.Data = {
	StoreName = "BazarPlayerData_v1", -- schema migrations are automatic; do not rename unless you want a wipe
	KeyPrefix = "Player_",
	AutoSaveSeconds = 60,
	LockStaleSeconds = 6 * 60,
	LoadRetryCount = 12,
	LoadRetryDelaySeconds = 5,
	SaveRetryCount = 4,
	UseMockStoreInStudioIfUnavailable = true,
}

Config.AntiExploit = {
	GlobalRatePerSecond = 30,
	GlobalBurst = 50,
	KickThreshold = 100,
	DecayPerSecond = 0.5,
	MovementCheckInterval = 0.25,
	SpeedTolerance = 1.5,
	SpeedLeewayStuds = 4,
	TeleportStuds = 80,
	MaxVerticalRiseStuds = 25,
	ViolationsBeforeCorrection = 3,
	SpawnGraceSeconds = 3,
}

Config.Languages = { "en", "sk" }

Config.Debug = {
	StudioGrantAllPasses = false, -- Studio only
	VerboseLogging = false,
}

return Config
