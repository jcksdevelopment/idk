--!strict
--[[
	PetController
	Renders every player's equipped pets as floating emoji buddies that
	follow their owner. Purely local and cosmetic: the server publishes the
	equipped pet ids in the "Pets" Player attribute; nothing is replicated
	per frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pets"))

local PetController = {}

type Buddy = { Part: Part, Index: number, Count: number }

local folder: Folder? = nil
local buddies: { [Player]: { Buddy } } = {}

local OFFSETS = {
	Vector3.new(-3, 1.5, 3),
	Vector3.new(3, 1.5, 3),
	Vector3.new(0, 2.5, 4.5),
}

local function clear(player: Player)
	local list = buddies[player]
	if list then
		for _, buddy in list do
			buddy.Part:Destroy()
		end
	end
	buddies[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local parent = folder
	local attribute = player:GetAttribute("Pets")
	if not parent or type(attribute) ~= "string" or attribute == "" then
		return
	end
	local ids = string.split(attribute, ",")
	local list: { Buddy } = {}
	for index, petId in ids do
		local def = Pets.Get(petId)
		if def and index <= #OFFSETS then
			local p = Instance.new("Part")
			p.Name = petId
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(1, 1, 1)

			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(2.6, 2.6)
			gui.LightInfluence = 0
			gui.MaxDistance = 90
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = def.Icon
			label.TextScaled = true
			label.Parent = gui
			gui.Parent = p

			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				p.CFrame = root.CFrame * CFrame.new(OFFSETS[index])
			end
			p.Parent = parent
			table.insert(list, { Part = p, Index = index, Count = #ids })
		end
	end
	buddies[player] = list
end

local function track(player: Player)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetController.Start()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "LocalPets"
	newFolder.Parent = Workspace
	folder = newFolder

	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		local alpha = math.clamp(dt * 8, 0, 1)
		for player, list in buddies do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				for _, buddy in list do
					local bob = math.sin(t * 3 + buddy.Index) * 0.4
					local target = root.CFrame * CFrame.new(OFFSETS[buddy.Index] + Vector3.new(0, bob, 0))
					buddy.Part.CFrame = buddy.Part.CFrame:Lerp(target, alpha)
				end
			end
		end
	end)
end

return PetController
