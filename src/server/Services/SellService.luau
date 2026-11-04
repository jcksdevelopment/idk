--!strict
--[[
	SellService
	The client sends ONLY an item id. The price is computed on the server from
	the server-owned record + catalog + server-tracked boost. Removing the item
	and paying out happen in one non-yielding block, so the same item can never
	be sold twice (double-fire, lag switch, or leaving mid-sale).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Valuation = require(Shared.Valuation)

local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
local ItemService = require(script.Parent.ItemService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)
local SyncService = require(script.Parent.SyncService)
local WorldService = require(script.Parent.WorldService)

local SellService = {}

local function requireCounter(player: Player): boolean
	if WorldService.IsNear(player, "SellCounter") then
		return true
	end
	FlagService.Flag(player, "SellOutOfRange", 2)
	SyncService.Notify(player, "error", "Head to the Sell Counter to cash out.")
	return false
end

local function onSellItem(player: Player, itemId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local item = data.Inventory[itemId]
	if not item then
		return -- already sold / never existed: duplicate requests die here
	end
	if item.State == "Repairing" then
		SyncService.Notify(player, "error", "That item is still on the workbench.")
		return
	end
	if not requireCounter(player) then
		return
	end

	-- Atomic section (no yields): price, remove, pay.
	local value = Valuation.SellValue(item, Rules.MoneyMultiplier(data))
	data.Inventory[itemId] = nil
	ItemService.AddCash(data, value, true)
	data.Stats.ItemsSold += 1

	SyncService.MarkDirty(player)
	local template = Items.Get(item.TemplateId)
	SyncService.Notify(player, "success", string.format("Sold %s for %s", if template then template.Name else "item", Format.Cash(value)))
end

local function onSellAllClean(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	if not requireCounter(player) then
		return
	end
	local data = profile.Data
	local multiplier = Rules.MoneyMultiplier(data)

	local toSell: { string } = {}
	for id, item in data.Inventory do
		if item.State == "Clean" then
			table.insert(toSell, id)
		end
	end
	if #toSell == 0 then
		SyncService.Notify(player, "info", "No clean items to sell yet.")
		return
	end

	local total = 0
	for _, id in toSell do
		local item = data.Inventory[id]
		if item then
			total += Valuation.SellValue(item, multiplier)
			data.Inventory[id] = nil
			data.Stats.ItemsSold += 1
		end
	end
	ItemService.AddCash(data, total, true)

	SyncService.MarkDirty(player)
	SyncService.Notify(player, "success", string.format("Sold %d items for %s", #toSell, Format.Cash(total)))
end

function SellService.Start()
	RemoteGuard.Bind("SellItem", { RatePerSecond = 6, Burst = 10, Args = { RemoteGuard.Validators.ItemId } }, onSellItem)
	RemoteGuard.Bind("SellAllClean", { RatePerSecond = 1, Burst = 2, Args = {} }, onSellAllClean)
end

return SellService
