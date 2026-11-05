--!strict
--[[
	FriendService
	Tracks which players in this server are Roblox friends, for the
	"play with friends" money bonus. Friendship is checked by the server with
	IsFriendsWith (the client is never asked).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local FriendService = {}

-- Fires with every player whose friend count changed.
FriendService.Changed = Signal.new() :: Signal.Signal<Player>

local friends: { [Player]: { [Player]: boolean } } = {}

local function link(a: Player, b: Player)
	friends[a] = friends[a] or {}
	friends[b] = friends[b] or {}
	friends[a][b] = true
	friends[b][a] = true
end

function FriendService.Count(player: Player): number
	local set = friends[player]
	if not set then
		return 0
	end
	local count = 0
	for other in set do
		if other.Parent == Players then
			count += 1
		end
	end
	return math.min(count, Config.Friends.MaxFriends)
end

function FriendService.Bonus(player: Player): number
	return FriendService.Count(player) * Config.Friends.BonusPerFriend
end

local function onPlayerAdded(player: Player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and isFriend and player.Parent == Players and other.Parent == Players then
				link(player, other)
				FriendService.Changed:Fire(player)
				FriendService.Changed:Fire(other)
			end
		end
	end
end

function FriendService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local set = friends[player]
		friends[player] = nil
		if set then
			for other in set do
				local otherSet = friends[other]
				if otherSet then
					otherSet[player] = nil
				end
				FriendService.Changed:Fire(other)
			end
		end
	end)
end

return FriendService
