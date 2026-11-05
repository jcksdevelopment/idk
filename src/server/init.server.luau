--!strict
--[[
	Server bootstrap.
	1. Create remotes (before anything can listen or fire).
	2. Start services in dependency order. DataService starts last because it
	   may yield while opening the DataStore; every other service is ready to
	   react to ProfileLoaded by then.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
Net.SetupServer()

local Services = script:WaitForChild("Services")

local START_ORDER = {
	"FlagService",
	"RemoteGuard",
	"GamePassService",
	"FriendService",
	"SocialService",
	"BadgeAwardService",
	"SyncService",
	"WorldService",
	"ProgressService",
	"PetService",
	"RequestService",
	"AntiExploitService",
	"ItemService",
	"RepairService",
	"SellService",
	"MonetizationService",
	"LeaderboardService",
	"DataService",
}

for _, name in START_ORDER do
	local module = Services:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Missing service " .. name)
	local service = (require :: any)(module)
	local ok, err = pcall(service.Start)
	if not ok then
		warn(string.format("[Server] %s failed to start: %s", name, tostring(err)))
	end
end

print("[Server] Bazar & Item Flipping Simulator ready")
