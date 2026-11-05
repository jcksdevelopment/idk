--!strict
--[[
	Events
	Date-driven seasonal events (UTC). Shared so the client can show what is
	running; the server re-checks before selling event boxes.
]]

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Events = {}

local function dayOfYear(month: number, day: number): number
	return month * 100 + day
end

function Events.IsActive(eventId: string, now: number?): boolean
	local debugEvent = Config.Debug.ForceEvent
	if debugEvent ~= "" and RunService:IsStudio() then
		return debugEvent == eventId
	end
	local def = (Config.Events :: any)[eventId]
	if not def then
		return false
	end
	local date = os.date("!*t", now or os.time()) :: any
	local today = dayOfYear(date.month, date.day)
	local startAt = dayOfYear(def.Start[1], def.Start[2])
	local endAt = dayOfYear(def.End[1], def.End[2])
	if startAt <= endAt then
		return today >= startAt and today <= endAt
	end
	return today >= startAt or today <= endAt -- wraps over New Year
end

function Events.ActiveList(now: number?): { string }
	local list = {}
	for eventId in Config.Events do
		if Events.IsActive(eventId, now) then
			table.insert(list, eventId)
		end
	end
	table.sort(list)
	return list
end

return Events
