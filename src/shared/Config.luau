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
	-- Roblox policy: in-game currency bought with Robux that can buy random
	-- rewards (our mystery boxes / eggs) makes those boxes "paid random items",
	-- which needs per-item odds + PolicyService restrictions. Keep this false
	-- unless you implement both (see docs/LAUNCH_PLAN.md, section 7.2).
	SellCurrencyForRobux = false,
	CurrencyProducts = { CashPackSmall = true }, -- products that sell in-game cash
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
	WinterGift = {
		Icon = "🎁",
		Price = 300,
		Order = 0,
		UnlockLevel = 1,
		Event = "Winter", -- only sold while the event is active; drops only event items
		Weights = { Trash = 50, Rare = 38, Legendary = 12 },
	},
	SpookyBox = {
		Icon = "🎃",
		Price = 300,
		Order = 0,
		UnlockLevel = 1,
		Event = "Halloween",
		Weights = { Trash = 50, Rare = 38, Legendary = 12 },
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
	ForceEvent = "", -- Studio only: "Winter" or "Halloween" to test an event any day
	VerboseLogging = false,
}

------------------------------------------------------------------------
-- v3: rebirth, achievements, lucky wheel, friends, leaderboard
------------------------------------------------------------------------

-- Rebirth ("New Start"): reset cash + level for a permanent money bonus.
-- Items, collection, quests and achievements are kept.
Config.Rebirth = {
	BaseLevel = 15, -- level needed for the first rebirth
	LevelPerRebirth = 5, -- each further rebirth needs this many more levels
	BaseCash = 25000, -- cash needed = BaseCash * (rebirths + 1)
	MoneyBonusPerRebirth = 0.25, -- +25% sell money forever, per rebirth
	MaxRebirths = 50,
}

-- Achievements unlock automatically and grant a reward + an overhead title.
-- Stat: a key of PlayerData.Stats, or "LifetimeEarned", "Level", "Rebirths", "Collection".
Config.Achievements = {
	{ Id = "FirstFlip", Icon = "🌱", Stat = "ItemsSold", Goal = 1, Reward = { Cash = 50 } },
	{ Id = "Repair50", Icon = "🔧", Stat = "ItemsRepaired", Goal = 50, Reward = { Cash = 500 } },
	{ Id = "Seller100", Icon = "💼", Stat = "ItemsSold", Goal = 100, Reward = { Cash = 2000 } },
	{ Id = "Crates250", Icon = "📦", Stat = "CratesOpened", Goal = 250, Reward = { Cash = 1500 } },
	{ Id = "Shiny1", Icon = "✨", Stat = "ShiniesFound", Goal = 1, Reward = { Tokens = 1 } },
	{ Id = "Legend10", Icon = "🏆", Stat = "LegendariesFound", Goal = 10, Reward = { Cash = 5000 } },
	{ Id = "Level20", Icon = "⭐", Stat = "Level", Goal = 20, Reward = { Cash = 3000 } },
	{ Id = "Rich", Icon = "💰", Stat = "LifetimeEarned", Goal = 100000, Reward = { BoostMinutes = 30 } },
	{ Id = "Rebirth1", Icon = "🔄", Stat = "Rebirths", Goal = 1, Reward = { Tokens = 2 } },
	{ Id = "Repair500", Icon = "🛠️", Stat = "ItemsRepaired", Goal = 500, Reward = { Tokens = 3 } },
	{ Id = "Shiny10", Icon = "🌈", Stat = "ShiniesFound", Goal = 10, Reward = { Cash = 10000 } },
	{ Id = "Collector", Icon = "📖", Stat = "Collection", Goal = 21, Reward = { Cash = 25000 } },
	{ Id = "Seller1000", Icon = "👑", Stat = "ItemsSold", Goal = 1000, Reward = { Tokens = 5 } },
	{ Id = "FirstPet", Icon = "🐾", Stat = "PetsHatched", Goal = 1, Reward = { Cash = 300 } },
	{ Id = "PetMaster", Icon = "🐉", Stat = "PetsHatched", Goal = 25, Reward = { Tokens = 3 } },
	{ Id = "StarTrainer", Icon = "⭐", Stat = "MaxPetStars", Goal = 1, Reward = { Tokens = 1 } },
	{ Id = "SuperStar", Icon = "🌟", Stat = "MaxPetStars", Goal = 2, Reward = { Cash = 8000 } },
	{ Id = "Festive", Icon = "🎉", Stat = "EventItemsFound", Goal = 6, Reward = { Cash = 5000 } },
}

-- Free Lucky Wheel. Never sold for Robux; one free spin per cooldown.
-- Cash prizes scale with level so the wheel stays exciting.
Config.Wheel = {
	CooldownSeconds = 4 * 60 * 60,
	CashLevelScale = 0.15, -- cash prize * (1 + level * this)
	Prizes = {
		{ Weight = 30, Reward = { Cash = 100 }, Icon = "💵" },
		{ Weight = 15, Reward = { Tokens = 1 }, Icon = "⚡" },
		{ Weight = 20, Reward = { Cash = 300 }, Icon = "💰" },
		{ Weight = 15, Reward = { BoostMinutes = 10 }, Icon = "🚀" },
		{ Weight = 8, Reward = { XP = 60 }, Icon = "⭐" },
		{ Weight = 8, Reward = { Cash = 1000 }, Icon = "💎" },
		{ Weight = 4, Reward = { Tokens = 3 }, Icon = "🎁" },
	},
}

-- Playing with friends: +10% sell money per friend in the same server.
Config.Friends = {
	BonusPerFriend = 0.1,
	MaxFriends = 3,
}

-- Seasonal events (UTC month/day, inclusive). Wrapping over New Year is fine.
Config.Events = {
	Winter = { Start = { 12, 1 }, End = { 1, 6 }, Icon = "❄️" },
	Halloween = { Start = { 10, 15 }, End = { 11, 2 }, Icon = "🎃" },
}

-- Pet helpers: hatched from eggs with in-game cash (never Robux), they
-- follow you and give small permanent bonuses while equipped.
-- Bonus kinds: Money (+% sell money), Repair (-% repair time),
--              XP (+% XP), Luck (+ shiny chance, absolute).
Config.Pets = {
	MaxEquipped = 3,
	MaxOwned = 30,
	MaxRepairReduction = 0.5,
	-- Caps on the team bonus so fused legendaries can't break the economy.
	MaxMoneyBonus = 1.5, -- at most +150% money from pets
	MaxXPBonus = 1.0, -- at most +100% XP
	MaxLuckBonus = 0.07, -- at most +7% shiny chance (base 3% -> 10%)
	-- Fusion: 3 identical pets (same kind + stars) -> 1 pet with one more star.
	MaxStars = 2,
	StarMultipliers = { [0] = 1, [1] = 2, [2] = 4 }, -- bonus multiplier per star level
	Eggs = {
		BasicEgg = { Icon = "🥚", Price = 500, UnlockLevel = 2, Order = 1, Weights = { Trash = 70, Rare = 25, Legendary = 5 } },
		GoldenEgg = { Icon = "🌟", Price = 5000, UnlockLevel = 6, Order = 2, Weights = { Trash = 35, Rare = 47, Legendary = 18 } },
	},
	SellValue = { Trash = 50, Rare = 300, Legendary = 2000 },
	List = {
		{ Id = "Puppy", Icon = "🐶", Rarity = "Trash", Bonus = "Money", Amount = 0.05 },
		{ Id = "Kitten", Icon = "🐱", Rarity = "Trash", Bonus = "Luck", Amount = 0.005 },
		{ Id = "Bunny", Icon = "🐰", Rarity = "Trash", Bonus = "Repair", Amount = 0.05 },
		{ Id = "Hamster", Icon = "🐹", Rarity = "Trash", Bonus = "XP", Amount = 0.05 },
		{ Id = "Fox", Icon = "🦊", Rarity = "Rare", Bonus = "Money", Amount = 0.12 },
		{ Id = "Owl", Icon = "🦉", Rarity = "Rare", Bonus = "Repair", Amount = 0.12 },
		{ Id = "Panda", Icon = "🐼", Rarity = "Rare", Bonus = "XP", Amount = 0.15 },
		{ Id = "Dragon", Icon = "🐉", Rarity = "Legendary", Bonus = "Money", Amount = 0.3 },
		{ Id = "Unicorn", Icon = "🦄", Rarity = "Legendary", Bonus = "Luck", Amount = 0.02 },
		{ Id = "Phoenix", Icon = "🦅", Rarity = "Legendary", Bonus = "Repair", Amount = 0.25 },
	},
}

-- Gift codes (share them on your group / socials). Each works once per player.
-- Codes are matched case-insensitively. Optional Event = "Winter" makes a code
-- work only while that event runs.
Config.Codes = {
	WELCOME = { Reward = { Cash = 250, Tokens = 1 } },
	BAZAR = { Reward = { Cash = 500 } },
	FLIPPER = { Reward = { BoostMinutes = 10 } },
	SNOWDAY = { Reward = { Cash = 1000, Tokens = 1 }, Event = "Winter" },
	SPOOKY = { Reward = { Cash = 1000, Tokens = 1 }, Event = "Halloween" },
}

-- First box of the day is free (UTC day). Encourages daily visits without pressure.
Config.FreeDailyBox = {
	Enabled = true,
	Crate = "JunkBox",
}

Config.Leaderboard = {
	StoreName = "BazarTopEarners_v1",
	RefreshSeconds = 120,
	Size = 10,
	Position = Vector3.new(44, 0, 8),
}

------------------------------------------------------------------------
-- v5 Launch update: images, badges, social bonuses, weekly challenge
------------------------------------------------------------------------

-- Uploaded image asset ids ("rbxassetid://123456"). Leave "" to keep the
-- emoji fallback. See docs/ART_PROMPTS.md for a ready prompt per image.
Config.Images = {
	Logo = "", -- loading screen logo (transparent PNG)
	Items = {
		RustySpoon = "", -- Rusty Spoon
		CrackedTeapot = "", -- Cracked Teapot
		MoldyBoot = "", -- Moldy Boot
		BrokenRadio = "", -- Broken Radio
		ChippedVase = "", -- Chipped Vase
		BentBell = "", -- Bent Bicycle Bell
		SqueakyDuck = "", -- Squeaky Rubber Duck
		DentedKettle = "", -- Dented Kettle
		VintageCamera = "", -- Vintage Camera
		BrassCompass = "", -- Brass Compass
		Gramophone = "", -- Old Gramophone
		PocketWatch = "", -- Silver Pocket Watch
		RetroConsole = "", -- Retro Game Console
		RobotToy = "", -- Wind-up Robot
		Telescope = "", -- Captain's Telescope
		GrandfatherClock = "", -- Antique Grandfather Clock
		GoldenSamovar = "", -- Golden Samovar
		PersianRug = "", -- Ancient Persian Rug
		JeweledMusicBox = "", -- Jeweled Music Box
		DragonEgg = "", -- Dragon Egg Statue
		PirateMap = "", -- Lost Pirate Map
		GingerCookie = "", -- Gingerbread Cookie
		WoollyMitten = "", -- Woolly Mitten
		SnowGlobe = "", -- Snow Globe
		IceSkates = "", -- Ice Skates
		MagicSnowman = "", -- Magic Snowman
		SantaSleigh = "", -- Santa's Sleigh
		CandyPile = "", -- Pile of Candy
		OldBroom = "", -- Witch's Old Broom
		GhostLantern = "", -- Ghost Lantern
		CatStatue = "", -- Lucky Cat Statue
		PumpkinKing = "", -- Pumpkin King
		MagicTopHat = "", -- Magician's Top Hat
	},
	Pets = {
		Puppy = "",
		Kitten = "",
		Bunny = "",
		Hamster = "",
		Fox = "",
		Owl = "",
		Panda = "",
		Dragon = "",
		Unicorn = "",
		Phoenix = "",
	},
	Crates = {
		JunkBox = "",
		AntiqueChest = "",
		WinterGift = "",
		SpookyBox = "",
		RoyalTreasure = "",
	},
	Eggs = {
		BasicEgg = "",
		GoldenEgg = "",
	},
	Shop = {
		VIPAutoCleaner = "",
		ExtraCapacity = "",
		InstantRepair = "",
		MoneyBoost2x = "",
		CashPackSmall = "",
	},
}

-- Real Roblox badges (shown on the player's profile). Create them in the
-- Creator Dashboard (Engagement -> Badges) and paste the Badge IDs. 0 = off.
Config.Badges = {
	Welcome = 0, -- awarded on first join
	FirstFlip = 0,
	Repair50 = 0,
	Seller100 = 0,
	Crates250 = 0,
	Shiny1 = 0,
	Legend10 = 0,
	Level20 = 0,
	Rich = 0,
	Rebirth1 = 0,
	Repair500 = 0,
	Shiny10 = 0,
	Collector = 0,
	Seller1000 = 0,
	FirstPet = 0,
	PetMaster = 0,
	StarTrainer = 0,
	SuperStar = 0,
	Festive = 0,
}

-- Social bonuses (server-verified, stack with everything else).
Config.Social = {
	GroupId = 0, -- your Roblox group id; members get GroupBonus. 0 = off
	GroupBonus = 0.1, -- +10% sell money for group members
	PremiumBonus = 0.1, -- +10% sell money for Roblox Premium members
}

-- One big challenge per UTC week (Monday-agnostic: week = day // 7).
Config.Weekly = {
	Pool = {
		{ Id = "SellItems", Event = "ItemSold", Goal = 150, Reward = { Cash = 5000, Tokens = 3, XP = 150 } },
		{ Id = "RepairItems", Event = "ItemRepaired", Goal = 100, Reward = { Cash = 5000, Tokens = 3, XP = 150 } },
		{ Id = "OpenCrates", Event = "CrateOpened", Goal = 120, Reward = { Cash = 5000, Tokens = 3, XP = 150 } },
		{ Id = "EarnCash", Event = "CashEarned", Goal = 60000, Reward = { Tokens = 5, BoostMinutes = 30, XP = 150 } },
	},
}

-- On join, open the Quests & Gifts panel automatically when a gift is waiting.
Config.AutoOpenDailyGift = true

return Config
