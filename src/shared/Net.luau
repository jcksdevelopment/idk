--!strict
--[[
	Net
	Declares every RemoteEvent in one place. The server creates them; the
	client waits for them. RemoteFunctions are intentionally not used: a
	server -> client InvokeClient can hang the server forever, and
	request/response is expressed as events + state sync instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.FolderName = "Remotes"

-- Client -> Server. Every one of these is validated + rate limited by RemoteGuard.
Net.ClientToServer = table.freeze({
	"BuyCrate", -- (crateKey: string)
	"StartRepair", -- (itemId: string)
	"CompleteRepair", -- (itemId: string)
	"SellItem", -- (itemId: string)
	"SellAllClean", -- ()
	"RequestInstantRepair", -- (itemId: string)
	"PromptProduct", -- (productKey: string)
	"PromptGamePass", -- (passKey: string)
	"RequestSync", -- ()
	"Scrub", -- (itemId: string)
	"ClaimDaily", -- ()
	"ClaimQuest", -- (index: number)
	"ClaimCollection", -- (rarity: string)
	"SetSetting", -- (key: string, value: boolean | string)
	"SkipTutorial", -- ()
	"Rebirth", -- ()
	"SpinWheel", -- ()
	"SetTitle", -- (achievementId: string) "" = none
	"BuyEgg", -- (eggKey: string)
	"EquipPet", -- (petUid: string, equip: boolean)
	"SellPet", -- (petUid: string)
	"FusePets", -- (petUid: string) 3 identical pets -> 1 with +1 star
	"RedeemCode", -- (code: string)
	"ClaimWeekly", -- ()
})

-- Server -> Client
Net.ServerToClient = table.freeze({
	"StateSync", -- (snapshot: Snapshot)
	"Notify", -- (kind: NotifyKind, localeKey: string, args: { string })
	"OpenPanel", -- (panel: string)
})

local cache: { [string]: RemoteEvent } = {}

function Net.SetupServer(): { [string]: RemoteEvent }
	assert(RunService:IsServer(), "Net.SetupServer must run on the server")
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if folder then
		folder:Destroy() -- never trust a pre-existing folder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = Net.FolderName

	for _, list in { Net.ClientToServer, Net.ServerToClient } do
		for _, name in list do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = newFolder
			cache[name] = remote
		end
	end

	newFolder.Parent = ReplicatedStorage
	return cache
end

function Net.Get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Net.FolderName)
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), "Remote " .. name .. " is not a RemoteEvent")
	cache[name] = remote
	return remote
end

return Net
