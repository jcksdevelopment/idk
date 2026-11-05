--!strict
--[[
	BadgeAwardService
	Awards real Roblox badges (Config.Badges) for the welcome visit and for
	achievements. Purely cosmetic for the player profile; failures are logged
	and retried on the next join, never block gameplay.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local BadgeAwardService = {}

local awarded: { [Player]: { [string]: boolean } } = {}

function BadgeAwardService.Award(player: Player, key: string)
	local badgeId = (Config.Badges :: any)[key]
	if type(badgeId) ~= "number" or badgeId == 0 then
		return
	end
	local set = awarded[player] or {}
	awarded[player] = set
	if set[key] then
		return
	end
	set[key] = true
	task.spawn(function()
		local okHas, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if okHas and has then
			return
		end
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		if not ok then
			set[key] = nil -- allow a retry later
			warn("[Badges] Could not award", key, badgeId, err)
		end
	end)
end

function BadgeAwardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		awarded[player] = nil
	end)
end

return BadgeAwardService
