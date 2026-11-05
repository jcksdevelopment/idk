--!strict
--[[
	RepairService
	Time-based repairs with full server authority.

	StartRepair   : server stamps RepairStartedAt / RepairEndsAt with os.time().
	CompleteRepair: the client's "repair done" is only a REQUEST. If os.time()
	                is still before RepairEndsAt the request is silently
	                dropped; if it is clearly early (beyond clock jitter) the
	                player is flagged.
	Instant Repair: consumes a token (bought via Developer Product). The
	                purchase itself is granted in MonetizationService.
	Scrub         : kid-friendly tap mini-game. Each tap removes a little time,
	                capped at MaxReductionRatio of the repair and rate limited,
	                so auto-clickers gain nothing beyond a fast human.
	VIP Auto-Cleaner: background loop that finishes due repairs and starts new
	                ones in free slots, without proximity requirements.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Valuation = require(Shared.Valuation)

local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
local GamePassService = require(script.Parent.GamePassService)
local ProgressService = require(script.Parent.ProgressService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)
local SyncService = require(script.Parent.SyncService)
local WorldService = require(script.Parent.WorldService)

local RepairService = {}

local function itemArg(item: Types.ItemRecord): string
	return "@item:" .. item.TemplateId
end

local function beginRepair(data: Types.PlayerData, item: Types.ItemRecord, now: number)
	item.State = "Repairing"
	item.RepairStartedAt = now
	item.RepairEndsAt = now + Rules.RepairSeconds(data, item.Rarity)
	item.ScrubSeconds = 0
end

local function finishRepair(player: Player, data: Types.PlayerData, item: Types.ItemRecord)
	item.State = "Clean"
	item.RepairStartedAt = nil
	item.RepairEndsAt = nil
	item.ScrubSeconds = 0
	data.Stats.ItemsRepaired += 1
	ProgressService.AddXP(player, data, Config.Progression.XP.Repaired[item.Rarity] or 1)
	ProgressService.Record(player, data, "ItemRepaired", 1)
end

local function onStartRepair(player: Player, itemId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local item = data.Inventory[itemId]
	if not item or item.State ~= "Dirty" then
		return -- stale UI or forged id; nothing to do
	end
	if not WorldService.IsNear(player, "Workbench") then
		FlagService.Flag(player, "StartRepairOutOfRange", 2)
		SyncService.Notify(player, "error", "N_NeedWorkbench")
		return
	end
	if Rules.ActiveRepairs(data) >= Rules.RepairSlots(player) then
		SyncService.Notify(player, "error", "N_BenchBusy")
		return
	end

	beginRepair(data, item, os.time())
	ProgressService.Record(player, data, "RepairStarted", 1)
	SyncService.MarkDirty(player)
end

local function onScrub(player: Player, itemId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local item = data.Inventory[itemId]
	if not item or item.State ~= "Repairing" or item.RepairEndsAt == nil then
		return
	end
	-- Cap relative to this repair's original length (pets may have shortened it).
	local original = (item.RepairEndsAt :: number) - (item.RepairStartedAt or 0) + item.ScrubSeconds
	local maxReduction = math.min(original, Valuation.RepairSeconds(item.Rarity)) * Config.Scrub.MaxReductionRatio
	local reduction = math.min(Config.Scrub.SecondsPerScrub, maxReduction - item.ScrubSeconds)
	if reduction <= 0 then
		return -- fully scrubbed; the rest of the timer must run
	end
	item.ScrubSeconds += reduction
	item.RepairEndsAt = (item.RepairEndsAt :: number) - reduction
	ProgressService.Record(player, data, "Scrub", 1)
	SyncService.MarkDirty(player)
end

local function onCompleteRepair(player: Player, itemId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local item = data.Inventory[itemId]
	if not item or item.State ~= "Repairing" or item.RepairEndsAt == nil then
		return
	end

	-- Same UTC clock as os.time(), with millisecond precision (scrubbing
	-- makes end times fractional).
	local now = DateTime.now().UnixTimestampMillis / 1000
	local endsAt = item.RepairEndsAt :: number
	if now < endsAt then
		-- Silently drop. Only flag when it is clearly not clock jitter.
		if endsAt - now > Config.Repair.EarlyToleranceSeconds then
			FlagService.Flag(player, string.format("RepairCompletedEarly(%.1fs)", endsAt - now), 8)
		end
		return
	end

	finishRepair(player, data, item)
	SyncService.MarkDirty(player)
	SyncService.Notify(player, "success", "N_Repaired", { itemArg(item) })
end

local function onRequestInstantRepair(player: Player, itemId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local item = data.Inventory[itemId]
	if not item or item.State == "Clean" then
		return
	end

	if data.InstantRepairTokens > 0 then
		data.InstantRepairTokens -= 1
		finishRepair(player, data, item)
		SyncService.MarkDirty(player)
		SyncService.Notify(player, "success", "N_InstantRepaired", { itemArg(item) })
		return
	end

	local productId = Config.DevProducts.InstantRepair
	if productId == 0 then
		SyncService.Notify(player, "error", "N_InstantNotConfigured")
		return
	end
	-- Remember the target; ProcessReceipt applies the token to it once paid.
	SyncService.SetPendingInstantRepair(player, itemId)
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- Called from ProcessReceipt. MUST NOT yield or error after mutating.
function RepairService.GrantInstantRepair(player: Player, data: Types.PlayerData)
	data.InstantRepairTokens += 1

	local target = SyncService.GetPendingInstantRepair(player)
	SyncService.SetPendingInstantRepair(player, nil)
	if target then
		local item = data.Inventory[target]
		if item and item.State ~= "Clean" then
			data.InstantRepairTokens -= 1
			finishRepair(player, data, item)
			SyncService.Notify(player, "success", "N_InstantRepaired", { itemArg(item) })
			return
		end
	end
	SyncService.Notify(player, "success", "N_TokenAdded")
end

local function vipTick()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		if not GamePassService.Has(player, "VIPAutoCleaner") then
			continue
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			continue
		end
		local data = profile.Data
		local changed = false

		local dirtyItems: { Types.ItemRecord } = {}
		for _, item in data.Inventory do
			if item.State == "Repairing" and item.RepairEndsAt ~= nil and now >= (item.RepairEndsAt :: number) then
				finishRepair(player, data, item)
				changed = true
			elseif item.State == "Dirty" then
				table.insert(dirtyItems, item)
			end
		end

		local freeSlots = Rules.RepairSlots(player) - Rules.ActiveRepairs(data)
		if freeSlots > 0 and #dirtyItems > 0 then
			table.sort(dirtyItems, function(a, b)
				return a.AcquiredAt < b.AcquiredAt
			end)
			for index = 1, math.min(freeSlots, #dirtyItems) do
				beginRepair(data, dirtyItems[index], now)
				changed = true
			end
		end

		if changed then
			SyncService.MarkDirty(player)
		end
	end
end

function RepairService.Start()
	local ItemId = RemoteGuard.Validators.ItemId

	RemoteGuard.Bind("StartRepair", { RatePerSecond = 4, Burst = 8, Args = { ItemId } }, onStartRepair)
	RemoteGuard.Bind("CompleteRepair", { RatePerSecond = 6, Burst = 12, Args = { ItemId } }, onCompleteRepair)
	RemoteGuard.Bind("Scrub", {
		RatePerSecond = Config.Scrub.RatePerSecond,
		Burst = Config.Scrub.RatePerSecond,
		Args = { ItemId },
		Silent = true,
	}, onScrub)
	RemoteGuard.Bind("RequestInstantRepair", { RatePerSecond = 1, Burst = 3, Args = { ItemId } }, onRequestInstantRepair)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		if purchased or productId ~= Config.DevProducts.InstantRepair then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			SyncService.SetPendingInstantRepair(player, nil)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Repair.VIPTickSeconds)
			local ok, err = pcall(vipTick)
			if not ok then
				warn("[RepairService] VIP tick failed:", err)
			end
		end
	end)
end

return RepairService
