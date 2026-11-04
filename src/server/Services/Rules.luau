--!strict
--[[
	Rules
	Derived gameplay values (capacity, repair slots, money multiplier). Kept in
	one place so every service computes them identically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local GamePassService = require(script.Parent.GamePassService)

local Rules = {}

function Rules.Capacity(player: Player): number
	local capacity = Config.Inventory.BaseCapacity
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

return Rules
