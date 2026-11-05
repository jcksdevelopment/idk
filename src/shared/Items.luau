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
	Event: string?, -- seasonal items only drop from their event box
	Set: string?, -- New Start markets (Vault, Galaxy) only drop from their box
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

	-- ❄️ Winter Festival (only from the Winter Gift box while the event runs)
	{ Id = "GingerCookie", Name = "Gingerbread Cookie", Rarity = "Trash", BaseValue = 30, Icon = "🍪", Event = "Winter" },
	{ Id = "WoollyMitten", Name = "Woolly Mitten", Rarity = "Trash", BaseValue = 26, Icon = "🧤", Event = "Winter" },
	{ Id = "SnowGlobe", Name = "Snow Globe", Rarity = "Rare", BaseValue = 160, Icon = "🔮", Event = "Winter" },
	{ Id = "IceSkates", Name = "Ice Skates", Rarity = "Rare", BaseValue = 150, Icon = "⛸️", Event = "Winter" },
	{ Id = "MagicSnowman", Name = "Magic Snowman", Rarity = "Legendary", BaseValue = 1200, Icon = "⛄", Event = "Winter" },
	{ Id = "SantaSleigh", Name = "Santa's Sleigh", Rarity = "Legendary", BaseValue = 1400, Icon = "🛷", Event = "Winter" },

	-- 🎃 Halloween (only from the Spooky Box while the event runs)
	{ Id = "CandyPile", Name = "Pile of Candy", Rarity = "Trash", BaseValue = 28, Icon = "🍬", Event = "Halloween" },
	{ Id = "OldBroom", Name = "Witch's Old Broom", Rarity = "Trash", BaseValue = 24, Icon = "🧹", Event = "Halloween" },
	{ Id = "GhostLantern", Name = "Ghost Lantern", Rarity = "Rare", BaseValue = 155, Icon = "🏮", Event = "Halloween" },
	{ Id = "CatStatue", Name = "Lucky Cat Statue", Rarity = "Rare", BaseValue = 145, Icon = "🐈", Event = "Halloween" },
	{ Id = "PumpkinKing", Name = "Pumpkin King", Rarity = "Legendary", BaseValue = 1250, Icon = "🎃", Event = "Halloween" },
	{ Id = "MagicTopHat", Name = "Magician's Top Hat", Rarity = "Legendary", BaseValue = 1150, Icon = "🎩", Event = "Halloween" },

	-- 🏛️ Treasure Vault market (unlocks after 1 New Start)
	{ Id = "SilverCutlery", Name = "Silver Cutlery Set", Rarity = "Trash", BaseValue = 60, Icon = "🍴", Set = "Vault" },
	{ Id = "PorcelainDoll", Name = "Porcelain Doll", Rarity = "Trash", BaseValue = 75, Icon = "🪆", Set = "Vault" },
	{ Id = "KnightHelmet", Name = "Knight's Helmet", Rarity = "Rare", BaseValue = 380, Icon = "🪖", Set = "Vault" },
	{ Id = "GoldenHarp", Name = "Golden Harp", Rarity = "Rare", BaseValue = 450, Icon = "🎻", Set = "Vault" },
	{ Id = "CrystalCrown", Name = "Crystal Crown", Rarity = "Legendary", BaseValue = 3200, Icon = "👑", Set = "Vault" },
	{ Id = "PharaohMask", Name = "Pharaoh's Mask", Rarity = "Legendary", BaseValue = 4000, Icon = "🗿", Set = "Vault" },

	-- 🚀 Galaxy Junk market (unlocks after 3 New Starts)
	{ Id = "MoonRock", Name = "Moon Rock", Rarity = "Trash", BaseValue = 180, Icon = "🌑", Set = "Galaxy" },
	{ Id = "SatelliteDish", Name = "Old Satellite Dish", Rarity = "Trash", BaseValue = 220, Icon = "📡", Set = "Galaxy" },
	{ Id = "RobotDog", Name = "Robot Dog", Rarity = "Rare", BaseValue = 1100, Icon = "🐕", Set = "Galaxy" },
	{ Id = "AlienLamp", Name = "Alien Lava Lamp", Rarity = "Rare", BaseValue = 1300, Icon = "💡", Set = "Galaxy" },
	{ Id = "MiniUFO", Name = "Mini UFO", Rarity = "Legendary", BaseValue = 9000, Icon = "🛸", Set = "Galaxy" },
	{ Id = "StarAtlas", Name = "Star Atlas", Rarity = "Legendary", BaseValue = 11000, Icon = "🌌", Set = "Galaxy" },
}

local byId: { [string]: ItemTemplate } = {}
local byRarity: { [string]: { ItemTemplate } } = { Trash = {}, Rare = {}, Legendary = {} }
local ordered: { ItemTemplate } = {}
local eventPools: { [string]: { [string]: { ItemTemplate } } } = {}
local eventOrdered: { [string]: { ItemTemplate } } = {}

for _, template in catalog do
	assert(byId[template.Id] == nil, "Duplicate item template id: " .. template.Id)
	table.freeze(template)
	byId[template.Id] = template
	local event = template.Event or template.Set -- events and markets share the pool mechanism
	if event then
		eventPools[event] = eventPools[event] or { Trash = {}, Rare = {}, Legendary = {} }
		eventOrdered[event] = eventOrdered[event] or {}
		table.insert(eventPools[event][template.Rarity], template)
		table.insert(eventOrdered[event], template)
	else
		table.insert(byRarity[template.Rarity], template)
		table.insert(ordered, template)
	end
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

-- Regular (non-event) items only: these make up the collection book goals.
function Items.All(): { ItemTemplate }
	return ordered
end

function Items.GetEventPool(event: string, rarity: Types.Rarity): { ItemTemplate }
	local pools = eventPools[event]
	return if pools then pools[rarity] else {}
end

function Items.EventItems(event: string): { ItemTemplate }
	return eventOrdered[event] or {}
end

function Items.IsRarity(value: unknown): boolean
	return value == "Trash" or value == "Rare" or value == "Legendary"
end

return table.freeze(Items)
