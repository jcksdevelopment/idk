--!strict
--[[
	Config
	Single source of truth for tunables, Robux product IDs and station layout.

	>>> INSERT YOUR IDS HERE <<<
	Replace every 0 in GamePasses / DevProducts with the IDs from the Creator
	Dashboard (Monetization -> Passes / Developer Products). An ID of 0 means
	"not configured": the shop shows the item as unavailable and the server
	refuses to prompt it.
]]

local Config = {}

Config.GamePasses = {
	VIPAutoCleaner = 0, -- Game Pass ID: background auto-repair + extra repair slots
	ExtraCapacity = 0, -- Game Pass ID: +20 inventory capacity
}

Config.DevProducts = {
	InstantRepair = 0, -- Developer Product ID: instantly finish one repair
	MoneyBoost2x = 0, -- Developer Product ID: 2x sell money for a limited time
	CashPackSmall = 0, -- Developer Product ID: flat cash bundle
}

-- Display metadata for the cash shop (prices are fetched live from Roblox).
Config.ShopDisplay = {
	DevProducts = {
		InstantRepair = {
			Title = "Instant Repair",
			Description = "Finish any repair right now. Unused repairs are saved as tokens.",
			Icon = "⚡",
			Ribbon = "POPULAR",
			Order = 1,
		},
		MoneyBoost2x = {
			Title = "2x Money Boost",
			Description = "Double sell value for 15 minutes. Stacks!",
			Icon = "💰",
			Ribbon = "BEST VALUE",
			Order = 2,
		},
		CashPackSmall = {
			Title = "Starter Cash Pack",
			Description = "+$2,500 bazaar cash, delivered instantly.",
			Icon = "💵",
			Ribbon = "",
			Order = 3,
		},
	},
	GamePasses = {
		VIPAutoCleaner = {
			Title = "VIP Auto-Cleaner",
			Description = "Repairs your junk in the background, +2 workbench slots.",
			Icon = "🤖",
			Ribbon = "VIP",
			Order = 1,
		},
		ExtraCapacity = {
			Title = "+20 Inventory",
			Description = "Carry 20 more items at once. Flip more, earn more.",
			Icon = "🎒",
			Ribbon = "",
			Order = 2,
		},
	},
}

Config.Products = {
	MoneyBoostMultiplier = 2,
	MoneyBoostDurationSeconds = 15 * 60,
	MoneyBoostMaxStackSeconds = 24 * 60 * 60,
	CashPackSmallAmount = 2500,
	PurchaseHistoryLimit = 100,
}

Config.Economy = {
	StartingCash = 100,
	DirtySellRatio = 0.35, -- unrepaired items sell for 35% of their clean value
	MaxCash = 1e15, -- hard cap to stay well inside float integer precision
}

Config.Inventory = {
	BaseCapacity = 10,
	ExtraCapacityBonus = 20,
}

Config.Repair = {
	BaseSlots = 1,
	VIPExtraSlots = 2,
	SecondsByRarity = {
		Trash = 8,
		Rare = 30,
		Legendary = 90,
	},
	-- Completing up to this many seconds early is treated as clock jitter:
	-- the request is dropped but the player is NOT flagged.
	EarlyToleranceSeconds = 2,
	VIPTickSeconds = 1,
}

-- Rarity weights per crate. JunkBox uses the canonical 70 / 25 / 5 split.
Config.Crates = {
	JunkBox = {
		DisplayName = "Mystery Junk Box",
		Icon = "📦",
		Price = 25,
		Order = 1,
		Weights = { Trash = 70, Rare = 25, Legendary = 5 },
	},
	AntiqueChest = {
		DisplayName = "Estate Sale Chest",
		Icon = "🧰",
		Price = 250,
		Order = 2,
		Weights = { Trash = 40, Rare = 45, Legendary = 15 },
	},
}

Config.QualityRange = { Min = 0.8, Max = 1.25 }

-- World stations. The server enforces InteractRadius for crate buying,
-- starting repairs and selling (anti auto-farm). Set RequireProximity to
-- false if you want a pure menu-driven game.
Config.Stations = {
	RequireProximity = true,
	InteractRadius = 18,
	ServerLeeway = 6, -- extra studs the server allows for latency
	Bazaar = { Position = Vector3.new(-24, 3, -20), Label = "Junk Bazaar", Color = Color3.fromRGB(230, 126, 34) },
	Workbench = { Position = Vector3.new(0, 3, -28), Label = "Repair Workbench", Color = Color3.fromRGB(52, 152, 219) },
	SellCounter = { Position = Vector3.new(24, 3, -20), Label = "Sell Counter", Color = Color3.fromRGB(46, 204, 113) },
}

Config.Data = {
	StoreName = "BazarPlayerData_v1",
	KeyPrefix = "Player_",
	AutoSaveSeconds = 60,
	-- A session lock older than this (no refresh) is considered dead and may be taken over.
	-- Must be comfortably larger than AutoSaveSeconds because autosave refreshes the lock.
	LockStaleSeconds = 6 * 60,
	LoadRetryCount = 12,
	LoadRetryDelaySeconds = 5,
	SaveRetryCount = 4,
	-- In Studio, fall back to an in-memory store if "Enable Studio Access to API Services" is off.
	UseMockStoreInStudioIfUnavailable = true,
}

Config.AntiExploit = {
	-- Remote spam protection: per-player budget across ALL remotes.
	GlobalRatePerSecond = 25,
	GlobalBurst = 40,
	-- Flag score: each suspicious action adds weight, decays over time.
	KickThreshold = 100,
	DecayPerSecond = 0.5,
	-- Movement validation
	MovementCheckInterval = 0.25,
	SpeedTolerance = 1.5, -- multiplier on WalkSpeed
	SpeedLeewayStuds = 4,
	TeleportStuds = 80, -- single-interval jump that is always treated as a teleport
	MaxVerticalRiseStuds = 25, -- per check interval (jumps are ~7.2 studs)
	ViolationsBeforeCorrection = 3,
	SpawnGraceSeconds = 3,
}

Config.Debug = {
	-- Studio only: pretend the player owns every pass (never applies in live servers).
	StudioGrantAllPasses = false,
	VerboseLogging = false,
}

return Config
