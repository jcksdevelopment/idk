--!strict
--[[
	StateController
	Holds the latest server snapshot. The client renders this state; it never
	edits it. Any action goes to the server as a request, and the result comes
	back as a new snapshot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local StateController = {}

StateController.Current = nil :: Types.Snapshot?
StateController.Changed = Signal.new() :: Signal.Signal<Types.Snapshot>

function StateController.Fire(remoteName: string, ...: any)
	Net.Get(remoteName):FireServer(...)
end

function StateController.FindItem(itemId: string): Types.ItemView?
	local snapshot = StateController.Current
	if not snapshot then
		return nil
	end
	for _, item in snapshot.Items do
		if item.Id == itemId then
			return item
		end
	end
	return nil
end

function StateController.ServerNow(): number
	return workspace:GetServerTimeNow()
end

function StateController.Start()
	Net.Get("StateSync").OnClientEvent:Connect(function(snapshot: Types.Snapshot)
		StateController.Current = snapshot
		StateController.Changed:Fire(snapshot)
	end)

	-- Ask until the first snapshot arrives (profile may still be loading).
	task.spawn(function()
		while StateController.Current == nil do
			StateController.Fire("RequestSync")
			task.wait(3)
		end
	end)
end

return StateController
