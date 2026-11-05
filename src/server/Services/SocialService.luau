--!strict
--[[
	SocialService
	Group-member and Roblox Premium money bonuses. Both are checked by the
	server (Player:IsInGroup, Player.MembershipType); the client cannot claim
	them. Premium bonuses also encourage Premium playtime, which earns the
	developer Premium Payouts.
]]

local GroupService = game:GetService("GroupService")
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

-- Player:IsInGroup is cached for the session, so re-checks use
-- GroupService:GetGroupsAsync, which reflects joining the group mid-session.
local function fetchInGroup(player: Player, fresh: boolean): boolean?
	if not fresh then
		local ok, result = pcall(player.IsInGroup, player, Config.Social.GroupId)
		return if ok then result == true else nil
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or type(groups) ~= "table" then
		return nil
	end
	for _, group in groups do
		if group.Id == Config.Social.GroupId then
			return true
		end
	end
	return false
end

local function checkGroup(player: Player, fresh: boolean?)
	if not SocialService.GroupEnabled() then
		return
	end
	for attempt = 1, 3 do
		local result = fetchInGroup(player, fresh == true)
		if result ~= nil then
			local changed = inGroup[player] ~= result
			inGroup[player] = result
			if changed or not fresh then
				SocialService.Changed:Fire(player)
			end
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
					task.spawn(checkGroup, player, true)
				end
			end
		end
	end)
end

return SocialService
