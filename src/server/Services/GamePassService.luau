--!strict
--[[
	GamePassService
	Server-side source of truth for game pass ownership.

	- Ownership is checked with UserOwnsGamePassAsync on join (with retries).
	- In-session purchases are picked up from PromptGamePassPurchaseFinished,
	  which is raised by the engine on the server and cannot be spoofed.
	- The client never tells the server what it owns.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

export type PassKey = string -- any key of Config.GamePasses

local GamePassService = {}

GamePassService.Changed = Signal.new() :: Signal.Signal<Player>

local owned: { [Player]: { [string]: boolean } } = {}

local function passKeyForId(passId: number): string?
	for key, id in Config.GamePasses do
		if id ~= 0 and id == passId then
			return key
		end
	end
	return nil
end

local function checkOwnership(player: Player, passId: number): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok then
			return result == true
		end
		task.wait(attempt)
	end
	return false
end

local function refresh(player: Player)
	local flags: { [string]: boolean } = owned[player] or {}
	owned[player] = flags
	local studioGrant = RunService:IsStudio() and Config.Debug.StudioGrantAllPasses
	for key, id in Config.GamePasses do
		if studioGrant then
			flags[key] = true
		elseif id ~= 0 and not flags[key] then
			flags[key] = checkOwnership(player, id)
		end
	end
	GamePassService.Changed:Fire(player)
end

function GamePassService.Has(player: Player, key: PassKey): boolean
	local flags = owned[player]
	return flags ~= nil and flags[key] == true
end

function GamePassService.GetPassId(key: string): number?
	local id = (Config.GamePasses :: any)[key]
	if type(id) == "number" and id ~= 0 then
		return id
	end
	return nil
end

function GamePassService.Prompt(player: Player, key: string): boolean
	local id = GamePassService.GetPassId(key)
	if not id then
		return false
	end
	if GamePassService.Has(player, key :: PassKey) then
		return false
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
	return true
end

function GamePassService.Start()
	Players.PlayerAdded:Connect(refresh)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if not key then
			return
		end
		local flags = owned[player] or {}
		owned[player] = flags
		flags[key] = true
		GamePassService.Changed:Fire(player)
	end)
end

return GamePassService
