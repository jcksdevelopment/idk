--!strict
--[[
	Rules
	Derived gameplay values and the few primitive mutations every service
	shares (cash, boost). Kept in one place so all services agree.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local Types = require(Shared.Types)
local GamePassService = require(script.Parent.GamePassService)

local Rules = {}

function Rules.Level(data: Types.PlayerData): number
	return Progression.LevelFromTotal(data.XP)
end

function Rules.Capacity(player: Player, data: Types.PlayerData): number
	local capacity = Config.Inventory.BaseCapacity + Progression.LevelCapacityBonus(Rules.Level(data))
	if GamePassService.Has(player, "ExtraCapacity") then
		capacity += Config.Inventory.ExtraCapacityBonus
	end
	return capacity
end

function Rules.RepairSlots(player: Player): number
	local slots = Config.Repair.BaseSlots
	if GamePassService.Has(player, "VIPAutoCleaner") then
		slots += Config.Repair.VIPExtraSlots
	end
	return slots
end

function Rules.MoneyMultiplier(data: Types.PlayerData): number
	if data.BoostEndsAt > os.time() then
		return Config.Products.MoneyBoostMultiplier
	end
	return 1
end

function Rules.InventoryCount(data: Types.PlayerData): number
	local count = 0
	for _ in data.Inventory do
		count += 1
	end
	return count
end

function Rules.ActiveRepairs(data: Types.PlayerData): number
	local count = 0
	for _, item in data.Inventory do
		if item.State == "Repairing" then
			count += 1
		end
	end
	return count
end

-- Adds cash (clamped). Returns the amount actually added.
function Rules.AddCash(data: Types.PlayerData, amount: number, countsAsEarned: boolean): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local before = data.Cash
	data.Cash = math.min(Config.Economy.MaxCash, data.Cash + math.floor(amount))
	local added = data.Cash - before
	if countsAsEarned then
		data.LifetimeEarned += added
	end
	return added
end

function Rules.ExtendBoost(data: Types.PlayerData, seconds: number)
	if seconds <= 0 then
		return
	end
	local now = os.time()
	local base = math.max(now, data.BoostEndsAt)
	data.BoostEndsAt = math.min(base + seconds, now + Config.Products.MoneyBoostMaxStackSeconds)
end

return Rules
