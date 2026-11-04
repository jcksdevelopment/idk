--!strict
--[[
	Items
	Static catalog of every item template. Values here are the ONLY source of
	item worth; clients never send values.
]]

local Types = require(script.Parent.Types)

export type ItemTemplate = {
	Id: string,
	Name: string,
	Rarity: Types.Rarity,
	BaseValue: number,
	Icon: string,
}

local Items = {}

local catalog: { ItemTemplate } = {
	-- Trash (cheap, fast repairs)
	{ Id = "RustySpoon", Name = "Rusty Spoon", Rarity = "Trash", BaseValue = 10, Icon = "🥄" },
	{ Id = "CrackedTeapot", Name = "Cracked Teapot", Rarity = "Trash", BaseValue = 16, Icon = "🫖" },
	{ Id = "MoldyBoot", Name = "Moldy Boot", Rarity = "Trash", BaseValue = 12, Icon = "🥾" },
	{ Id = "BrokenRadio", Name = "Broken Radio", Rarity = "Trash", BaseValue = 24, Icon = "📻" },
	{ Id = "ChippedVase", Name = "Chipped Vase", Rarity = "Trash", BaseValue = 20, Icon = "🏺" },
	{ Id = "BentBell", Name = "Bent Bicycle Bell", Rarity = "Trash", BaseValue = 14, Icon = "🔔" },

	-- Rare
	{ Id = "VintageCamera", Name = "Vintage Camera", Rarity = "Rare", BaseValue = 95, Icon = "📷" },
	{ Id = "BrassCompass", Name = "Brass Compass", Rarity = "Rare", BaseValue = 80, Icon = "🧭" },
	{ Id = "Gramophone", Name = "Old Gramophone", Rarity = "Rare", BaseValue = 140, Icon = "🎺" },
	{ Id = "PocketWatch", Name = "Silver Pocket Watch", Rarity = "Rare", BaseValue = 120, Icon = "⌚" },
	{ Id = "RetroConsole", Name = "Retro Game Console", Rarity = "Rare", BaseValue = 110, Icon = "🎮" },

	-- Legendary
	{ Id = "GrandfatherClock", Name = "Antique Grandfather Clock", Rarity = "Legendary", BaseValue = 650, Icon = "🕰️" },
	{ Id = "GoldenSamovar", Name = "Golden Samovar", Rarity = "Legendary", BaseValue = 800, Icon = "🏆" },
	{ Id = "PersianRug", Name = "Ancient Persian Rug", Rarity = "Legendary", BaseValue = 950, Icon = "🧶" },
	{ Id = "JeweledMusicBox", Name = "Jeweled Music Box", Rarity = "Legendary", BaseValue = 720, Icon = "💎" },
}

local byId: { [string]: ItemTemplate } = {}
local byRarity: { [string]: { ItemTemplate } } = { Trash = {}, Rare = {}, Legendary = {} }

for _, template in catalog do
	assert(byId[template.Id] == nil, "Duplicate item template id: " .. template.Id)
	byId[template.Id] = table.freeze(template)
	table.insert(byRarity[template.Rarity], template)
end

Items.Rarities = table.freeze({ "Trash", "Rare", "Legendary" }) :: { Types.Rarity }

Items.RarityColors = table.freeze({
	Trash = Color3.fromRGB(149, 165, 166),
	Rare = Color3.fromRGB(52, 152, 219),
	Legendary = Color3.fromRGB(241, 196, 15),
}) :: { [string]: Color3 }

function Items.Get(templateId: string): ItemTemplate?
	return byId[templateId]
end

function Items.GetByRarity(rarity: Types.Rarity): { ItemTemplate }
	return byRarity[rarity]
end

function Items.IsRarity(value: unknown): boolean
	return value == "Trash" or value == "Rare" or value == "Legendary"
end

return table.freeze(Items)
