--!strict
--[[
	RepairController
	When a repair's server-issued end time has passed, ask the server to
	complete it. Timing uses workspace:GetServerTimeNow() so the request lands
	after the server's os.time() deadline. The server re-validates anyway.
]]

local StateController = require(script.Parent.StateController)

local RepairController = {}

local RESEND_SECONDS = 2
local SAFETY_MARGIN = 0.35

local lastSent: { [string]: number } = {}

local function tick()
	local snapshot = StateController.Current
	if not snapshot then
		return
	end
	local now = StateController.ServerNow()
	local seen: { [string]: boolean } = {}
	for _, item in snapshot.Items do
		local endsAt = item.RepairEndsAt
		if item.State == "Repairing" and endsAt then
			seen[item.Id] = true
			local sentAt = lastSent[item.Id]
			if now >= endsAt + SAFETY_MARGIN and (sentAt == nil or os.clock() - sentAt > RESEND_SECONDS) then
				lastSent[item.Id] = os.clock()
				StateController.Fire("CompleteRepair", item.Id)
			end
		end
	end
	for id in lastSent do
		if not seen[id] then
			lastSent[id] = nil
		end
	end
end

function RepairController.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			tick()
		end
	end)
end

return RepairController
