--!strict
--[[
	PetService
	Pet helpers: hatch (in-game cash only), equip, send home.
	- The pet is rolled with server RNG; the client only sends an egg key.
	- Pet ids are server GUIDs and are looked up in the caller's profile only.
	- Bonuses are applied server-side through Rules.PetBonus.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Pets = require(Shared.Pets)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Rules = require(script.Parent.Rules)
local SyncService = require(script.Parent.SyncService)

local PetService = {}

local rng = Random.new()

local function countPets(data: Types.PlayerData): (number, number)
	local owned, equipped = 0, 0
	for _, pet in data.Pets do
		owned += 1
		if pet.Equipped then
			equipped += 1
		end
	end
	return owned, equipped
end

local function rollPet(weights: { [string]: number }): Pets.PetDef?
	local total = 0
	for _, rarity in Items.Rarities do
		if #Pets.ByRarity(rarity) > 0 then
			total += math.max(0, weights[rarity] or 0)
		end
	end
	local roll = rng:NextNumber() * total
	for _, rarity in Items.Rarities do
		local pool = Pets.ByRarity(rarity)
		if #pool > 0 then
			roll -= math.max(0, weights[rarity] or 0)
			if roll < 0 then
				return pool[rng:NextInteger(1, #pool)]
			end
		end
	end
	return nil
end

local function onBuyEgg(player: Player, eggKey: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local egg = (Config.Pets.Eggs :: any)[eggKey]
	if not egg then
		return
	end
	local data = profile.Data
	if Rules.Level(data) < egg.UnlockLevel then
		SyncService.Notify(player, "error", "N_EggLocked", { tostring(egg.UnlockLevel) })
		return
	end
	local owned, equipped = countPets(data)
	if owned >= Config.Pets.MaxOwned then
		SyncService.Notify(player, "error", "N_PetsFull")
		return
	end
	if data.Cash < egg.Price then
		SyncService.Notify(player, "error", "N_NotEnoughCash")
		return
	end
	local def = rollPet(egg.Weights)
	if not def then
		return
	end

	-- Atomic: pay, hatch, auto-equip if there is room.
	data.Cash -= egg.Price
	local uid = HttpService:GenerateGUID(false)
	while data.Pets[uid] do
		uid = HttpService:GenerateGUID(false)
	end
	data.Pets[uid] = { Id = uid, PetId = def.Id, Equipped = equipped < Config.Pets.MaxEquipped, Stars = 0 }
	data.Stats.PetsHatched += 1

	SyncService.Notify(player, "levelup", "N_PetHatched", { "@pet:" .. def.Id })
	ProgressService.Record(player, data, "PetHatched", 1)
	SyncService.MarkDirty(player)
end

local function onEquipPet(player: Player, uid: string, equip: boolean)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local pet = data.Pets[uid]
	if not pet or pet.Equipped == equip then
		return
	end
	if equip then
		local _, equipped = countPets(data)
		if equipped >= Config.Pets.MaxEquipped then
			SyncService.Notify(player, "error", "N_PetsEquipFull", { tostring(Config.Pets.MaxEquipped) })
			return
		end
	end
	pet.Equipped = equip
	SyncService.MarkDirty(player)
end

local function onSellPet(player: Player, uid: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local pet = data.Pets[uid]
	local def = pet and Pets.Get(pet.PetId)
	if not pet or not def then
		return
	end
	local value = (Config.Pets.SellValue :: any)[def.Rarity] or 10
	-- Atomic: remove, pay.
	data.Pets[uid] = nil
	Rules.AddCash(data, value, false)
	SyncService.Notify(player, "success", "N_PetSold", { "@pet:" .. def.Id, Format.Cash(value) })
	SyncService.MarkDirty(player)
end

-- Fuse: the chosen pet + 2 more of the same kind and star level become one
-- pet with +1 star. Unequipped duplicates are consumed first.
local function onFusePets(player: Player, uid: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local base = data.Pets[uid]
	if not base then
		return
	end
	if base.Stars >= Config.Pets.MaxStars then
		SyncService.Notify(player, "info", "N_FuseMax")
		return
	end
	local candidates: { Types.PetRecord } = {}
	for otherUid, pet in data.Pets do
		if otherUid ~= uid and pet.PetId == base.PetId and pet.Stars == base.Stars then
			table.insert(candidates, pet)
		end
	end
	if #candidates < 2 then
		SyncService.Notify(player, "error", "N_FuseNeedThree")
		return
	end
	table.sort(candidates, function(a, b)
		if a.Equipped ~= b.Equipped then
			return not a.Equipped -- consume resting pets first
		end
		return a.Id < b.Id
	end)
	-- Atomic: remove two, upgrade the base.
	data.Pets[candidates[1].Id] = nil
	data.Pets[candidates[2].Id] = nil
	base.Stars += 1
	SyncService.Notify(player, "levelup", "N_PetFused", { "@pet:" .. base.PetId })
	ProgressService.CheckAchievements(player, data)
	SyncService.MarkDirty(player)
end

function PetService.Start()
	local V = RemoteGuard.Validators
	RemoteGuard.Bind("BuyEgg", {
		RatePerSecond = 2,
		Burst = 4,
		Args = { V.KeyOf(Config.Pets.Eggs :: any) },
	}, onBuyEgg)
	RemoteGuard.Bind("EquipPet", {
		RatePerSecond = 4,
		Burst = 8,
		Args = {
			V.ItemId,
			function(value: unknown): boolean
				return type(value) == "boolean"
			end,
		},
	}, onEquipPet)
	RemoteGuard.Bind("SellPet", { RatePerSecond = 3, Burst = 6, Args = { V.ItemId } }, onSellPet)
	RemoteGuard.Bind("FusePets", { RatePerSecond = 2, Burst = 4, Args = { V.ItemId } }, onFusePets)
end

return PetService
