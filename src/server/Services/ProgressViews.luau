--!strict
--[[
	ProgressViews
	Pure, read-only projections of progression data for snapshots.
	(No dependencies on other services, so SyncService can use it freely.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
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
	for index, entry in data.Quests.Entries do
		local def = questDefs[entry.Id]
		if def then
			table.insert(views, {
				Index = index,
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

local weeklyDefs: { [string]: any } = {}
for _, def in Config.Weekly.Pool do
	weeklyDefs[def.Id] = def
end

function ProgressViews.WeeklyDef(id: string): any
	return weeklyDefs[id]
end

function ProgressViews.ThisWeek(): number
	return ProgressViews.Today() // 7
end

function ProgressViews.Weekly(data: Types.PlayerData): Types.WeeklyView?
	local def = weeklyDefs[data.Weekly.Id]
	if not def then
		return nil
	end
	return {
		Id = def.Id,
		Goal = def.Goal,
		Progress = math.min(data.Weekly.Progress, def.Goal),
		Claimed = data.Weekly.Claimed,
		Reward = def.Reward,
		ResetsAt = (data.Weekly.Week + 1) * 7 * 86400,
	}
end

-- Current value of an achievement stat (all server-owned data).
function ProgressViews.StatValue(data: Types.PlayerData, stat: string): number
	if stat == "LifetimeEarned" then
		return data.LifetimeEarned
	elseif stat == "Level" then
		return Progression.LevelFromTotal(data.XP)
	elseif stat == "Rebirths" then
		return data.Rebirths
	elseif string.match(stat, "^%a+Items$") and (Config.Sets :: any)[string.match(stat, "^(%a+)Items$") or ""] then
		-- "<Set>Items" (VaultItems, GalaxyItems, DinoItems, …): market items found
		local set = string.match(stat, "^(%a+)Items$")
		local count = 0
		for templateId in data.Collection do
			local template = Items.Get(templateId)
			if template and template.Set == set then
				count += 1
			end
		end
		return count
	elseif stat == "UpgradeLevels" then
		local total = 0
		for _, level in data.Upgrades do
			total += level
		end
		return total
	elseif stat == "MaxPetStars" then
		local best = 0
		for _, pet in data.Pets do
			best = math.max(best, pet.Stars or 0)
		end
		return best
	elseif stat == "EventItemsFound" then
		local count = 0
		for templateId in data.Collection do
			local template = Items.Get(templateId)
			if template and template.Event then
				count += 1
			end
		end
		return count
	elseif stat == "Collection" then
		local count = 0
		for templateId in data.Collection do
			local template = Items.Get(templateId)
			if template and not template.Event and not template.Set then
				count += 1
			end
		end
		return count
	end
	local value = (data.Stats :: any)[stat]
	return if type(value) == "number" then value else 0
end

function ProgressViews.AchievementGoal(def: any): number
	if def.Stat == "Collection" then
		return math.min(def.Goal, #Items.All())
	end
	return def.Goal
end

function ProgressViews.AchievementProgress(data: Types.PlayerData): { [string]: number }
	local progress: { [string]: number } = {}
	for _, def in Config.Achievements do
		progress[def.Id] = math.min(ProgressViews.StatValue(data, def.Stat), ProgressViews.AchievementGoal(def))
	end
	return progress
end

return ProgressViews
