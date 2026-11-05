--!strict
--[[
	RequestService
	"Customer requests": every few minutes a customer asks for one specific
	item. Selling that item CLEAN before the request expires pays
	Config.Requests.Multiplier times the normal price.
	Everything (which item, timing, payout) is decided on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local SyncService = require(script.Parent.SyncService)

local RequestService = {}

local rng = Random.new()

local function rollTemplate(): string
	local weights = Config.Requests.Weights
	local total = 0
	for _, rarity in Items.Rarities do
		total += weights[rarity] or 0
	end
	local roll = rng:NextNumber() * total
	for _, rarity in Items.Rarities do
		roll -= weights[rarity] or 0
		if roll < 0 then
			local pool = Items.GetByRarity(rarity)
			return pool[rng:NextInteger(1, #pool)].Id
		end
	end
	return Items.All()[1].Id
end

-- Starts a new request when none is active and the cooldown has passed.
function RequestService.Ensure(player: Player, data: Types.PlayerData): boolean
	local request = data.Request
	local now = os.time()
	if request.TemplateId ~= "" and now >= request.ExpiresAt then
		-- Expired unfulfilled: short pause, then a new customer.
		request.TemplateId = ""
		request.NextAt = now + Config.Requests.CooldownSeconds
		SyncService.MarkDirty(player)
	end
	if request.TemplateId == "" and now >= request.NextAt then
		request.TemplateId = rollTemplate()
		request.ExpiresAt = now + Config.Requests.DurationSeconds
		SyncService.MarkDirty(player)
		return true
	end
	return false
end

-- Called by SellService inside its atomic block. Returns the price multiplier
-- (1 when the item doesn't match) and completes the request when it does.
function RequestService.TryFulfill(player: Player, data: Types.PlayerData, item: Types.ItemRecord): number
	local request = data.Request
	if item.State ~= "Clean" or request.TemplateId ~= item.TemplateId or os.time() >= request.ExpiresAt then
		return 1
	end
	request.TemplateId = ""
	request.NextAt = os.time() + Config.Requests.CooldownSeconds
	SyncService.MarkDirty(player)
	return Config.Requests.Multiplier
end

function RequestService.Start()
	DataService.ProfileLoaded:Connect(function(player, profile)
		RequestService.Ensure(player, profile.Data)
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in Players:GetPlayers() do
				local profile = DataService.GetProfile(player)
				if profile then
					RequestService.Ensure(player, profile.Data)
				end
			end
		end
	end)
end

return RequestService
