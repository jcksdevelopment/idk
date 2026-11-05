--!strict
--[[
	ItemService
	Item generation (server RNG only) and crate purchases.

	- Rarity, shiny chance and quality are rolled with the server's Random.
	- Item IDs are server-generated GUIDs: a client can only refer to items it
	  was told about; it can never mint or choose one.
	- Level lock, capacity, cash check, deduction and insertion happen in one
	  non-yielding block: no window for double-spend or half-done purchases.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Events = require(Shared.Events)
local Items = require(Shared.Items)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
local ProgressService = require(script.Parent.ProgressService)
local ProgressViews = require(script.Parent.ProgressViews)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)
local SyncService = require(script.Parent.SyncService)
local WorldService = require(script.Parent.WorldService)

local ItemService = {}

local rng = Random.new()

function ItemService.RollRarity(weights: { [string]: number }): Types.Rarity
	local total = 0
	for _, rarity in Items.Rarities do
		total += math.max(0, weights[rarity] or 0)
	end
	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, rarity in Items.Rarities do
		cumulative += math.max(0, weights[rarity] or 0)
		if roll < cumulative then
			return rarity
		end
	end
	return "Trash"
end

function ItemService.CreateItem(data: Types.PlayerData, rarity: Types.Rarity, event: string?): Types.ItemRecord
	local pool = if event then Items.GetEventPool(event, rarity) else Items.GetByRarity(rarity)
	if #pool == 0 then
		pool = Items.GetByRarity(rarity)
	end
	local template = pool[rng:NextInteger(1, #pool)]

	local id = HttpService:GenerateGUID(false)
	while data.Inventory[id] do
		id = HttpService:GenerateGUID(false)
	end

	local range = Config.QualityRange
	local quality = math.floor((range.Min + rng:NextNumber() * (range.Max - range.Min)) * 100 + 0.5) / 100

	return {
		Id = id,
		TemplateId = template.Id,
		Rarity = template.Rarity,
		State = "Dirty",
		Quality = quality,
		Shiny = rng:NextNumber() < Config.Shiny.Chance + Rules.PetBonus(data, "Luck"),
		AcquiredAt = os.time(),
		RepairStartedAt = nil,
		RepairEndsAt = nil,
		ScrubSeconds = 0,
	}
end

-- Kept for callers that predate Rules.AddCash.
function ItemService.AddCash(data: Types.PlayerData, amount: number, countsAsEarned: boolean)
	Rules.AddCash(data, amount, countsAsEarned)
end

local function onBuyCrate(player: Player, crateKey: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local crate = (Config.Crates :: any)[crateKey]
	if not crate then
		return
	end

	if not WorldService.IsNear(player, "Bazaar") then
		FlagService.Flag(player, "BuyCrateOutOfRange", 2)
		SyncService.Notify(player, "error", "N_NeedBazaar")
		return
	end

	local data = profile.Data
	if crate.Event and not Events.IsActive(crate.Event) then
		SyncService.Notify(player, "error", "N_EventOver")
		return
	end
	if Rules.Level(data) < crate.UnlockLevel then
		SyncService.Notify(player, "error", "N_CrateLocked", { tostring(crate.UnlockLevel) })
		return
	end
	if Rules.InventoryCount(data) >= Rules.Capacity(player, data) then
		SyncService.Notify(player, "error", "N_InventoryFull")
		return
	end
	local today = ProgressViews.Today()
	local isFree = Config.FreeDailyBox.Enabled and crateKey == Config.FreeDailyBox.Crate and data.LastFreeBoxDay ~= today
	local price = if isFree then 0 else crate.Price
	if data.Cash < price then
		SyncService.Notify(player, "error", "N_NotEnoughCash")
		return
	end

	-- Atomic section (no yields): pay, roll, insert, progress.
	data.Cash -= price
	if isFree then
		data.LastFreeBoxDay = today
		SyncService.Notify(player, "success", "N_FreeBox")
	end
	local item = ItemService.CreateItem(data, ItemService.RollRarity(crate.Weights), crate.Event)
	data.Inventory[item.Id] = item
	data.Stats.CratesOpened += 1

	SyncService.Notify(player, "reveal", "N_Found", { item.Rarity, item.TemplateId, if item.Shiny then "1" else "0" })
	if item.Shiny then
		SyncService.Notify(player, "levelup", "N_ShinyFound")
	end

	ProgressService.Discover(player, data, item)
	ProgressService.AddXP(player, data, Config.Progression.XP.CrateOpened)
	ProgressService.Record(player, data, "CrateOpened", 1)
	SyncService.MarkDirty(player)
end

function ItemService.Start()
	RemoteGuard.Bind("BuyCrate", {
		RatePerSecond = 3,
		Burst = 5,
		Args = { RemoteGuard.Validators.KeyOf(Config.Crates :: any) },
	}, onBuyCrate)
end

return ItemService
