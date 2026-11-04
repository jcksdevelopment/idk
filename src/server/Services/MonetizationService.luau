--!strict
--[[
	MonetizationService
	ProcessReceipt + server-side purchase prompting.

	ProcessReceipt contract (why this is safe):
	- Roblox keeps retrying a receipt until we return PurchaseGranted, on this
	  or any later server the player joins.
	- We only return PurchaseGranted after a DataStore write that CONTAINS
	  the grant has committed (DataService.SaveNow). If anything fails - player
	  not here, profile not loaded / releasing, DataStore error, lock lost, Lua
	  error - we return NotProcessedYet and Roblox retries later.
	- Idempotency: the PurchaseId is recorded in the profile in the SAME
	  non-yielding block that applies the grant. On a retry the id is already
	  present (either in memory, or in the stored copy if the save landed), so
	  the item is never granted twice; we just persist and acknowledge.
	- Because grant + history live in one session-locked record, a player
	  leaving mid-purchase can never cause a double grant or a lost purchase:
	  either the release save contains both, or neither (and Roblox retries).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local GamePassService = require(script.Parent.GamePassService)
local ItemService = require(script.Parent.ItemService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RepairService = require(script.Parent.RepairService)
local SyncService = require(script.Parent.SyncService)

local MonetizationService = {}

-- Grants MUST be synchronous (no yields) and must not error after they start
-- mutating data, so a grant is either fully applied or not at all.
type Grant = (player: Player, data: Types.PlayerData) -> ()

local grantsByKey: { [string]: Grant } = {
	InstantRepair = function(player, data)
		RepairService.GrantInstantRepair(player, data)
	end,

	MoneyBoost2x = function(player, data)
		local now = os.time()
		local base = math.max(now, data.BoostEndsAt)
		data.BoostEndsAt = math.min(base + Config.Products.MoneyBoostDurationSeconds, now + Config.Products.MoneyBoostMaxStackSeconds)
		SyncService.Notify(player, "success", string.format("💰 2x Money active for %s!", Format.Duration(data.BoostEndsAt - now)))
	end,

	CashPackSmall = function(player, data)
		ItemService.AddCash(data, Config.Products.CashPackSmallAmount, false)
		SyncService.Notify(player, "success", "💵 " .. Format.Cash(Config.Products.CashPackSmallAmount) .. " added!")
	end,
}

local grantsByProductId: { [number]: Grant } = {}

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local productId = receipt.ProductId
	local purchaseId = receipt.PurchaseId
	if type(productId) ~= "number" or type(purchaseId) ~= "string" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grant = grantsByProductId[productId]
	if not grant then
		warn("[Monetization] Receipt for unknown product id", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.WaitForProfile(player, 20)
	if not profile or not profile.Active then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = profile.Data
	if not table.find(data.PurchaseHistory, purchaseId) then
		-- Atomic section (no yields): grant + record.
		grant(player, data)
		table.insert(data.PurchaseHistory, purchaseId)
		while #data.PurchaseHistory > Config.Products.PurchaseHistoryLimit do
			table.remove(data.PurchaseHistory, 1)
		end
		data.Stats.RobuxPurchases += 1
		SyncService.MarkDirty(player)
	end

	-- Only acknowledge once a save containing the grant has committed.
	if DataService.SaveNow(profile) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function onPromptProduct(player: Player, productKey: string)
	local productId = (Config.DevProducts :: any)[productKey]
	if type(productId) ~= "number" or productId == 0 then
		SyncService.Notify(player, "error", "This item is not on sale yet.")
		return
	end
	if productKey == "InstantRepair" then
		-- Bought from the shop (no target): it becomes a token.
		SyncService.SetPendingInstantRepair(player, nil)
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function onPromptGamePass(player: Player, passKey: string)
	if GamePassService.Has(player, passKey :: any) then
		SyncService.Notify(player, "info", "You already own this pass!")
		return
	end
	if not GamePassService.Prompt(player, passKey) then
		SyncService.Notify(player, "error", "This pass is not on sale yet.")
	end
end

function MonetizationService.Start()
	for key, id in Config.DevProducts do
		local grant = grantsByKey[key]
		if id ~= 0 and grant then
			grantsByProductId[id] = grant
		elseif id == 0 then
			warn(string.format("[Monetization] DevProduct '%s' has no id configured (Config.DevProducts)", key))
		end
	end
	for key, id in Config.GamePasses do
		if id == 0 then
			warn(string.format("[Monetization] GamePass '%s' has no id configured (Config.GamePasses)", key))
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
		local ok, result = pcall(processReceipt, receipt)
		if ok then
			return result
		end
		warn("[Monetization] ProcessReceipt error:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	RemoteGuard.Bind("PromptProduct", {
		RatePerSecond = 1,
		Burst = 3,
		Args = { RemoteGuard.Validators.KeyOf(Config.DevProducts :: any) },
	}, onPromptProduct)

	RemoteGuard.Bind("PromptGamePass", {
		RatePerSecond = 1,
		Burst = 3,
		Args = { RemoteGuard.Validators.KeyOf(Config.GamePasses :: any) },
	}, onPromptGamePass)
end

return MonetizationService
