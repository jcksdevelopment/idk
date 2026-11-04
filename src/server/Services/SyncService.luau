--!strict
--[[
	SyncService
	Replicates a read-only snapshot of a player's state to THAT player only.
	Mutations call MarkDirty(); snapshots are coalesced and sent once per frame.
	Also maintains server-owned leaderstats for the player list.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local Valuation = require(Shared.Valuation)

local DataService = require(script.Parent.DataService)
local GamePassService = require(script.Parent.GamePassService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)

local SyncService = {}

local dirty: { [Player]: boolean } = {}
local pendingInstantRepair: { [Player]: string } = {}

local function buildSnapshot(player: Player, data: Types.PlayerData): Types.Snapshot
	local multiplier = Rules.MoneyMultiplier(data)
	local views: { Types.ItemView } = {}
	for _, item in data.Inventory do
		local template = Items.Get(item.TemplateId)
		table.insert(views, {
			Id = item.Id,
			TemplateId = item.TemplateId,
			Name = if template then template.Name else item.TemplateId,
			Icon = if template then template.Icon else "?",
			Rarity = item.Rarity,
			State = item.State,
			RepairStartedAt = item.RepairStartedAt,
			RepairEndsAt = item.RepairEndsAt,
			SellValue = Valuation.SellValue(item, multiplier),
			CleanValue = math.floor(Valuation.CleanValue(item) * multiplier),
			AcquiredAt = item.AcquiredAt,
		})
	end
	table.sort(views, function(a, b)
		if a.AcquiredAt == b.AcquiredAt then
			return a.Id < b.Id
		end
		return a.AcquiredAt > b.AcquiredAt
	end)

	return {
		Cash = data.Cash,
		LifetimeEarned = data.LifetimeEarned,
		Items = views,
		Capacity = Rules.Capacity(player),
		RepairSlots = Rules.RepairSlots(player),
		ActiveRepairs = Rules.ActiveRepairs(data),
		InstantRepairTokens = data.InstantRepairTokens,
		BoostEndsAt = data.BoostEndsAt,
		MoneyMultiplier = multiplier,
		Passes = {
			VIPAutoCleaner = GamePassService.Has(player, "VIPAutoCleaner"),
			ExtraCapacity = GamePassService.Has(player, "ExtraCapacity"),
		},
		PendingInstantRepair = pendingInstantRepair[player],
		ServerTime = os.time(),
	}
end

local function updateLeaderstats(player: Player, data: Types.PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = folder
		local flips = Instance.new("IntValue")
		flips.Name = "Flips"
		flips.Parent = folder
		folder.Parent = player
		leaderstats = folder
	end
	local cashValue = (leaderstats :: Instance):FindFirstChild("Cash") :: IntValue?
	local flipsValue = (leaderstats :: Instance):FindFirstChild("Flips") :: IntValue?
	if cashValue then
		cashValue.Value = math.floor(math.min(data.Cash, 2 ^ 53))
	end
	if flipsValue then
		flipsValue.Value = data.Stats.ItemsSold
	end
end

local function flush()
	if next(dirty) == nil then
		return
	end
	local remote = Net.Get("StateSync")
	for player in dirty do
		dirty[player] = nil
		local profile = DataService.GetProfile(player)
		if profile then
			remote:FireClient(player, buildSnapshot(player, profile.Data))
			updateLeaderstats(player, profile.Data)
		end
	end
end

function SyncService.MarkDirty(player: Player)
	dirty[player] = true
end

function SyncService.Notify(player: Player, kind: Types.NotifyKind, text: string)
	Net.Get("Notify"):FireClient(player, kind, text)
end

function SyncService.OpenPanel(player: Player, panel: string)
	Net.Get("OpenPanel"):FireClient(player, panel)
end

-- RepairService records which item a pending Instant Repair purchase targets.
function SyncService.SetPendingInstantRepair(player: Player, itemId: string?)
	pendingInstantRepair[player] = itemId
	dirty[player] = true
end

function SyncService.GetPendingInstantRepair(player: Player): string?
	return pendingInstantRepair[player]
end

function SyncService.Start()
	RunService.Heartbeat:Connect(flush)
	RemoteGuard.Bind("RequestSync", { RatePerSecond = 0.5, Burst = 3, Args = {} }, function(player: Player)
		SyncService.MarkDirty(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		SyncService.MarkDirty(player)
	end)
	GamePassService.Changed:Connect(function(player)
		SyncService.MarkDirty(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		pendingInstantRepair[player] = nil
	end)
end

return SyncService
