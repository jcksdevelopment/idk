--!strict
--[[
	Types
	Shared type definitions. These describe data shapes only; nothing in here is
	trusted on the server when it comes from a client.
]]

export type Rarity = "Trash" | "Rare" | "Legendary"
export type ItemState = "Dirty" | "Repairing" | "Clean"

export type Reward = {
	Cash: number?,
	Tokens: number?,
	BoostMinutes: number?,
	XP: number?,
}

-- Persistent, server-owned record of one inventory item.
export type ItemRecord = {
	Id: string,
	TemplateId: string,
	Rarity: Rarity,
	State: ItemState,
	Quality: number,
	Shiny: boolean,
	AcquiredAt: number,
	RepairStartedAt: number?,
	RepairEndsAt: number?,
	ScrubSeconds: number, -- seconds already scrubbed off the current repair
}

export type PlayerStats = {
	CratesOpened: number,
	ItemsSold: number,
	ItemsRepaired: number,
	RobuxPurchases: number,
	ShiniesFound: number,
}

export type Moderation = {
	TotalFlags: number,
	LastFlagAt: number,
	LastFlagReason: string,
}

export type QuestEntry = { Id: string, Progress: number, Claimed: boolean }
export type QuestState = { Day: number, Entries: { QuestEntry } }
export type DailyState = { Streak: number, LastClaimDay: number }
export type Settings = { Sound: boolean, Music: boolean, Language: string }

-- Everything that is persisted to the DataStore for one player.
export type PlayerData = {
	SchemaVersion: number,
	Cash: number,
	LifetimeEarned: number,
	XP: number, -- total XP; level is derived (Progression.FromTotal)
	Inventory: { [string]: ItemRecord },
	InstantRepairTokens: number,
	BoostEndsAt: number,
	PurchaseHistory: { string },
	Collection: { [string]: boolean }, -- templateId -> discovered
	ShinyCollection: { [string]: boolean },
	CollectionClaims: { [string]: boolean }, -- rarity -> reward claimed
	Quests: QuestState,
	Daily: DailyState,
	TutorialStep: number,
	Settings: Settings,
	Stats: PlayerStats,
	Moderation: Moderation,
}

-- Read-only view of an item sent to the owning client for display.
export type ItemView = {
	Id: string,
	TemplateId: string,
	Icon: string,
	Rarity: Rarity,
	State: ItemState,
	Shiny: boolean,
	RepairStartedAt: number?,
	RepairEndsAt: number?,
	ScrubSeconds: number,
	SellValue: number,
	CleanValue: number,
	AcquiredAt: number,
}

export type PassFlags = {
	VIPAutoCleaner: boolean,
	ExtraCapacity: boolean,
}

export type QuestView = {
	Id: string,
	Goal: number,
	Progress: number,
	Claimed: boolean,
	Reward: Reward,
}

export type DailyView = {
	CanClaim: boolean,
	NextDay: number, -- 1..7, the calendar day the next claim gives
	NextClaimAt: number,
}

-- Full state snapshot replicated server -> owning client.
export type Snapshot = {
	Cash: number,
	LifetimeEarned: number,
	Level: number,
	XPInLevel: number,
	XPNeeded: number,
	Items: { ItemView },
	Capacity: number,
	RepairSlots: number,
	ActiveRepairs: number,
	InstantRepairTokens: number,
	BoostEndsAt: number,
	MoneyMultiplier: number,
	Passes: PassFlags,
	PendingInstantRepair: string?,
	Quests: { QuestView },
	QuestsResetAt: number,
	Daily: DailyView,
	Collection: { [string]: boolean },
	ShinyCollection: { [string]: boolean },
	CollectionClaims: { [string]: boolean },
	TutorialStep: number,
	Settings: Settings,
	ServerTime: number,
}

export type NotifyKind = "success" | "error" | "info" | "reveal" | "levelup"

return nil
