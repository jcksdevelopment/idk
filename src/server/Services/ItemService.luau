--!strict
--[[
	ItemService
	Item generation (server RNG only) and crate purchases.

	- Rarity is rolled with the server's Random object using the crate's weights.
	- Item IDs are server-generated GUIDs, so a client can only ever refer to
	  items it was told about; it can never mint or choose one.
	- Cash check, deduction and item insertion happen in one non-yielding
	  block, so there is no window in which a second request (or a leave /
	  save) can observe a half-finished purchase.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
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

function ItemService.CreateItem(data: Types.PlayerData, rarity: Types.Rarity): Types.ItemRecord
	local pool = Items.GetByRarity(rarity)
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
		AcquiredAt = os.time(),
		RepairStartedAt = nil,
		RepairEndsAt = nil,
	}
end

function ItemService.AddCash(data: Types.PlayerData, amount: number, countsAsEarned: boolean)
	if amount <= 0 or amount ~= amount then
		return
	end
	data.Cash = math.min(Config.Economy.MaxCash, data.Cash + amount)
	if countsAsEarned then
		data.LifetimeEarned += amount
	end
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
		SyncService.Notify(player, "error", "Walk up to the Junk Bazaar to buy crates.")
		return
	end

	local data = profile.Data
	if Rules.InventoryCount(data) >= Rules.Capacity(player) then
		SyncService.Notify(player, "error", "Inventory full! Sell some junk or grab +20 Inventory in the shop.")
		return
	end
	if data.Cash < crate.Price then
		SyncService.Notify(player, "error", "Not enough cash for that crate.")
		return
	end

	-- Atomic section (no yields): pay, roll, insert.
	data.Cash -= crate.Price
	local item = ItemService.CreateItem(data, ItemService.RollRarity(crate.Weights))
	data.Inventory[item.Id] = item
	data.Stats.CratesOpened += 1

	SyncService.MarkDirty(player)
	local template = Items.Get(item.TemplateId)
	local name = if template then template.Name else item.TemplateId
	SyncService.Notify(player, "reveal", string.format("%s|%s|%s", item.Rarity, name, if template then template.Icon else ""))
end

function ItemService.Start()
	RemoteGuard.Bind("BuyCrate", {
		RatePerSecond = 3,
		Burst = 5,
		Args = { RemoteGuard.Validators.KeyOf(Config.Crates :: any) },
	}, onBuyCrate)
end

return ItemService
