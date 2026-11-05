--!strict
-- Workshop upgrade math shared by server (authoritative), client (display) and tests.

local Config = require(script.Parent.Config)

local Upgrades = {}

export type UpgradeDef = {
	Icon: string,
	MaxLevel: number,
	BaseCost: number,
	Growth: number,
	PerLevel: number,
}

function Upgrades.Def(key: string): UpgradeDef?
	return (Config.Upgrades :: any)[key]
end

-- Price to go from `level` to `level + 1` (nil when maxed / unknown).
function Upgrades.Cost(key: string, level: number): number?
	local def = Upgrades.Def(key)
	if not def or level >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * def.Growth ^ level / 5 + 0.5) * 5
end

-- Total effect at a level (e.g. 0.15 = +15%, or 4 = +4 slots).
function Upgrades.Effect(key: string, level: number): number
	local def = Upgrades.Def(key)
	if not def then
		return 0
	end
	return def.PerLevel * math.clamp(level, 0, def.MaxLevel)
end

return table.freeze(Upgrades)
