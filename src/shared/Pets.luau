--!strict
-- Pet catalog lookup (definitions live in Config.Pets).

local Config = require(script.Parent.Config)

export type PetDef = {
	Id: string,
	Icon: string,
	Rarity: string,
	Bonus: string, -- "Money" | "Repair" | "XP" | "Luck"
	Amount: number,
}

local Pets = {}

local byId: { [string]: PetDef } = {}
local byRarity: { [string]: { PetDef } } = { Trash = {}, Rare = {}, Legendary = {} }

for _, def in Config.Pets.List :: { PetDef } do
	byId[def.Id] = def
	table.insert(byRarity[def.Rarity], def)
end

function Pets.Get(petId: string): PetDef?
	return byId[petId]
end

function Pets.ByRarity(rarity: string): { PetDef }
	return byRarity[rarity] or {}
end

return table.freeze(Pets)
