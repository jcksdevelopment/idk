--!strict
--[[
	Rules
	Derived gameplay values and the few primitive mutations every service
	shares (cash, boost). Kept in one place so all services agree.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local Progression = require(Shared.Progression)
local Types = require(Shared.Types)
local FriendService = require(script.Parent.FriendService)
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

function Rules.RebirthBonus(data: Types.PlayerData): number
	return data.Rebirths * Config.Rebirth.MoneyBonusPerRebirth
end

-- Boost (2x) * (1 + rebirth bonus) * (1 + friends bonus). Server-authoritative.
function Rules.MoneyMultiplier(player: Player, data: Types.PlayerData): number
	local multiplier = if data.BoostEndsAt > os.time() then Config.Products.MoneyBoostMultiplier else 1
	multiplier *= 1 + Rules.RebirthBonus(data)
	multiplier *= 1 + FriendService.Bonus(player)
	multiplier *= 1 + Rules.PetBonus(data, "Money")
	return multiplier
end

-- Sum of one bonus kind over equipped pets (Money / Repair / XP / Luck).
function Rules.PetBonus(data: Types.PlayerData, kind: string): number
	local total = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			local def = Pets.Get(pet.PetId)
			if def and def.Bonus == kind then
				total += def.Amount * (Config.Pets.StarMultipliers[pet.Stars or 0] or 1)
			end
		end
	end
	if kind == "Repair" then
		return math.min(total, Config.Pets.MaxRepairReduction)
	end
	return total
end

-- Repair duration after pet bonuses.
function Rules.RepairSeconds(data: Types.PlayerData, rarity: Types.Rarity): number
	local base = Config.Repair.SecondsByRarity[rarity] or 30
	return math.max(1, base * (1 - Rules.PetBonus(data, "Repair")))
end

function Rules.RebirthRequirement(data: Types.PlayerData): (number, number)
	local r = Config.Rebirth
	return r.BaseLevel + data.Rebirths * r.LevelPerRebirth, r.BaseCash * (data.Rebirths + 1)
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
