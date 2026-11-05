--!strict
--[[
	SocialService
	Group-member and Roblox Premium money bonuses. Both are checked by the
	server (Player:IsInGroup, Player.MembershipType); the client cannot claim
	them. Premium bonuses also encourage Premium playtime, which earns the
	developer Premium Payouts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local SocialService = {}

SocialService.Changed = Signal.new() :: Signal.Signal<Player>

local inGroup: { [Player]: boolean } = {}

function SocialService.GroupEnabled(): boolean
	return Config.Social.GroupId ~= 0
end

function SocialService.InGroup(player: Player): boolean
	return inGroup[player] == true
end

function SocialService.IsPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

function SocialService.Bonus(player: Player): number
	local bonus = 0
	if SocialService.InGroup(player) then
		bonus += Config.Social.GroupBonus
	end
	if SocialService.IsPremium(player) then
		bonus += Config.Social.PremiumBonus
	end
	return bonus
end

local function checkGroup(player: Player)
	if not SocialService.GroupEnabled() then
		return
	end
	for attempt = 1, 3 do
		local ok, result = pcall(player.IsInGroup, player, Config.Social.GroupId)
		if ok then
			inGroup[player] = result == true
			SocialService.Changed:Fire(player)
			return
		end
		task.wait(attempt * 2)
	end
end

function SocialService.Start()
	Players.PlayerAdded:Connect(checkGroup)
	for _, player in Players:GetPlayers() do
		task.spawn(checkGroup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inGroup[player] = nil
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		SocialService.Changed:Fire(player)
	end)
	-- Re-check group membership every few minutes so players who join the
	-- group mid-session get their bonus without rejoining.
	task.spawn(function()
		while true do
			task.wait(180)
			for _, player in Players:GetPlayers() do
				if not inGroup[player] then
					task.spawn(checkGroup, player)
				end
			end
		end
	end)
end

return SocialService
