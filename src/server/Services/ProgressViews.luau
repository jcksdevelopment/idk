--!strict
--[[
	ProgressViews
	Pure, read-only projections of progression data for snapshots.
	(No dependencies on other services, so SyncService can use it freely.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local Types = require(Shared.Types)

local ProgressViews = {}

local questDefs: { [string]: any } = {}
for _, def in Config.Quests.Pool do
	questDefs[def.Id] = def
end

function ProgressViews.QuestDef(id: string): any
	return questDefs[id]
end

function ProgressViews.Today(): number
	return Progression.Day(os.time())
end

function ProgressViews.Quests(data: Types.PlayerData): { Types.QuestView }
	local views: { Types.QuestView } = {}
	for _, entry in data.Quests.Entries do
		local def = questDefs[entry.Id]
		if def then
			table.insert(views, {
				Id = entry.Id,
				Goal = def.Goal,
				Progress = math.min(entry.Progress, def.Goal),
				Claimed = entry.Claimed,
				Reward = def.Reward,
			})
		end
	end
	return views
end

function ProgressViews.NextDailyDay(data: Types.PlayerData, today: number): number
	local daily = data.Daily
	if daily.LastClaimDay == today - 1 or daily.LastClaimDay == today then
		return (daily.Streak % #Config.DailyRewards) + 1
	end
	return 1
end

function ProgressViews.Daily(data: Types.PlayerData): Types.DailyView
	local today = ProgressViews.Today()
	return {
		CanClaim = data.Daily.LastClaimDay ~= today,
		NextDay = ProgressViews.NextDailyDay(data, today),
		NextClaimAt = (today + 1) * 86400,
	}
end

return ProgressViews
