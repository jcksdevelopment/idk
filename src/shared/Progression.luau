--!strict
-- Level curve shared by server (authoritative) and client (display).

local Config = require(script.Parent.Config)

local Progression = {}

-- XP needed to go from `level` to `level + 1`.
function Progression.XPForLevel(level: number): number
	local p = Config.Progression
	return p.BaseXP + (level - 1) * p.XPGrowth
end

-- Returns level, XP into the current level, XP needed for the next level.
function Progression.FromTotal(totalXP: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, totalXP)
	while level < Config.Progression.MaxLevel and remaining >= Progression.XPForLevel(level) do
		remaining -= Progression.XPForLevel(level)
		level += 1
	end
	return level, remaining, Progression.XPForLevel(level)
end

function Progression.LevelFromTotal(totalXP: number): number
	local level = Progression.FromTotal(totalXP)
	return level
end

function Progression.LevelCapacityBonus(level: number): number
	local inv = Config.Inventory
	return math.min(inv.MaxLevelBonus, (level // inv.LevelBonusEvery) * inv.LevelBonusSlots)
end

function Progression.Day(unixTime: number): number
	return unixTime // 86400
end

return table.freeze(Progression)
