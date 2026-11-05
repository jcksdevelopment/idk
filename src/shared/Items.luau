--!strict
--[[
	Items
	Static catalog of every item template. Values here are the ONLY source of
	item worth; clients never send values. Display names are localized in
	Locale (key "Item_<Id>"); Name here is the English fallback.
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
	-- Trash
	{ Id = "RustySpoon", Name = "Rusty Spoon", Rarity = "Trash", BaseValue = 10, Icon = "🥄" },
	{ Id = "CrackedTeapot", Name = "Cracked Teapot", Rarity = "Trash", BaseValue = 16, Icon = "🫖" },
	{ Id = "MoldyBoot", Name = "Moldy Boot", Rarity = "Trash", BaseValue = 12, Icon = "🥾" },
	{ Id = "BrokenRadio", Name = "Broken Radio", Rarity = "Trash", BaseValue = 24, Icon = "📻" },
	{ Id = "ChippedVase", Name = "Chipped Vase", Rarity = "Trash", BaseValue = 20, Icon = "🏺" },
	{ Id = "BentBell", Name = "Bent Bicycle Bell", Rarity = "Trash", BaseValue = 14, Icon = "🔔" },
	{ Id = "SqueakyDuck", Name = "Squeaky Rubber Duck", Rarity = "Trash", BaseValue = 18, Icon = "🦆" },
	{ Id = "DentedKettle", Name = "Dented Kettle", Rarity = "Trash", BaseValue = 22, Icon = "🍳" },

	-- Rare
	{ Id = "VintageCamera", Name = "Vintage Camera", Rarity = "Rare", BaseValue = 95, Icon = "📷" },
	{ Id = "BrassCompass", Name = "Brass Compass", Rarity = "Rare", BaseValue = 80, Icon = "🧭" },
	{ Id = "Gramophone", Name = "Old Gramophone", Rarity = "Rare", BaseValue = 140, Icon = "🎺" },
	{ Id = "PocketWatch", Name = "Silver Pocket Watch", Rarity = "Rare", BaseValue = 120, Icon = "⌚" },
	{ Id = "RetroConsole", Name = "Retro Game Console", Rarity = "Rare", BaseValue = 110, Icon = "🎮" },
	{ Id = "RobotToy", Name = "Wind-up Robot", Rarity = "Rare", BaseValue = 105, Icon = "🤖" },
	{ Id = "Telescope", Name = "Captain's Telescope", Rarity = "Rare", BaseValue = 130, Icon = "🔭" },

	-- Legendary
	{ Id = "GrandfatherClock", Name = "Antique Grandfather Clock", Rarity = "Legendary", BaseValue = 650, Icon = "🕰️" },
	{ Id = "GoldenSamovar", Name = "Golden Samovar", Rarity = "Legendary", BaseValue = 800, Icon = "🏆" },
	{ Id = "PersianRug", Name = "Ancient Persian Rug", Rarity = "Legendary", BaseValue = 950, Icon = "🧶" },
	{ Id = "JeweledMusicBox", Name = "Jeweled Music Box", Rarity = "Legendary", BaseValue = 720, Icon = "💎" },
	{ Id = "DragonEgg", Name = "Dragon Egg Statue", Rarity = "Legendary", BaseValue = 1100, Icon = "🥚" },
	{ Id = "PirateMap", Name = "Lost Pirate Map", Rarity = "Legendary", BaseValue = 880, Icon = "🗺️" },
}

local byId: { [string]: ItemTemplate } = {}
local byRarity: { [string]: { ItemTemplate } } = { Trash = {}, Rare = {}, Legendary = {} }
local ordered: { ItemTemplate } = {}

for _, template in catalog do
	assert(byId[template.Id] == nil, "Duplicate item template id: " .. template.Id)
	table.freeze(template)
	byId[template.Id] = template
	table.insert(byRarity[template.Rarity], template)
	table.insert(ordered, template)
end

Items.Rarities = table.freeze({ "Trash", "Rare", "Legendary" }) :: { Types.Rarity }

Items.RarityColors = table.freeze({
	Trash = Color3.fromRGB(170, 180, 190),
	Rare = Color3.fromRGB(70, 170, 255),
	Legendary = Color3.fromRGB(255, 205, 40),
}) :: { [string]: Color3 }

function Items.Get(templateId: string): ItemTemplate?
	return byId[templateId]
end

function Items.GetByRarity(rarity: Types.Rarity): { ItemTemplate }
	return byRarity[rarity]
end

function Items.All(): { ItemTemplate }
	return ordered
end

function Items.IsRarity(value: unknown): boolean
	return value == "Trash" or value == "Rare" or value == "Legendary"
end

return table.freeze(Items)
