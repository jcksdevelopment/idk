--!strict
--[[
	FlagService
	Central "suspicion score" for each player. Detections call Flag() with a
	weight. The score decays over time so honest players who trip a heuristic
	once (lag spike, clock jitter) are never punished, while sustained abuse
	crosses KickThreshold and is removed.

	Flags are logged and a running total is persisted to the player's profile
	(Moderation.TotalFlags) for later review / analytics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local DataService = require(script.Parent.DataService)

local FlagService = {}

type Entry = { Score: number, LastUpdate: number, Kicked: boolean }

local entries: { [Player]: Entry } = {}

local function getEntry(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { Score = 0, LastUpdate = os.clock(), Kicked = false }
		entries[player] = entry
	end
	return entry
end

local function decay(entry: Entry)
	local now = os.clock()
	local elapsed = now - entry.LastUpdate
	entry.Score = math.max(0, entry.Score - elapsed * Config.AntiExploit.DecayPerSecond)
	entry.LastUpdate = now
end

function FlagService.Flag(player: Player, reason: string, weight: number)
	if not player:IsDescendantOf(Players) then
		return
	end
	local entry = getEntry(player)
	if entry.Kicked then
		return
	end
	decay(entry)
	entry.Score += weight

	warn(string.format("[AntiExploit] %s (%d) flagged: %s (+%d, score %.1f)", player.Name, player.UserId, reason, weight, entry.Score))

	local profile = DataService.GetProfile(player)
	if profile then
		local moderation = profile.Data.Moderation
		moderation.TotalFlags += 1
		moderation.LastFlagAt = os.time()
		moderation.LastFlagReason = string.sub(reason, 1, 100)
	end

	if entry.Score >= Config.AntiExploit.KickThreshold then
		entry.Kicked = true
		warn(string.format("[AntiExploit] Kicking %s (%d): score %.1f", player.Name, player.UserId, entry.Score))
		player:Kick("Unexpected client behaviour detected.")
	end
end

function FlagService.GetScore(player: Player): number
	local entry = entries[player]
	if not entry then
		return 0
	end
	decay(entry)
	return entry.Score
end

function FlagService.Start()
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return FlagService
