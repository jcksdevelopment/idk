--!strict
--[[
	Valuation
	Pure functions that compute item worth from SERVER-OWNED records.
	The server uses this authoritatively; the client only uses it for display.
]]

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)
local Types = require(script.Parent.Types)

local Valuation = {}

function Valuation.CleanValue(item: Types.ItemRecord): number
	local template = Items.Get(item.TemplateId)
	if not template then
		return 0
	end
	local value = template.BaseValue * item.Quality
	if item.Shiny then
		value *= Config.Shiny.ValueMultiplier
	end
	return math.max(1, math.floor(value))
end

function Valuation.SellValue(item: Types.ItemRecord, moneyMultiplier: number): number
	local value = Valuation.CleanValue(item)
	if item.State ~= "Clean" then
		value *= Config.Economy.DirtySellRatio
	end
	return math.max(1, math.floor(value * moneyMultiplier))
end

function Valuation.RepairSeconds(rarity: Types.Rarity): number
	return Config.Repair.SecondsByRarity[rarity] or 30
end

return table.freeze(Valuation)
