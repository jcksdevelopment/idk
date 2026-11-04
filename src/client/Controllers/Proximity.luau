--!strict
-- Client-side proximity check used ONLY for UX hints / button states.
-- The server performs its own authoritative check.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Proximity = {}

function Proximity.IsNear(stationKey: string): boolean
	if not Config.Stations.RequireProximity then
		return true
	end
	local station = (Config.Stations :: any)[stationKey]
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not station or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - station.Position).Magnitude <= Config.Stations.InteractRadius
end

return Proximity
