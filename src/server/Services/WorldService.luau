--!strict
--[[
	WorldService
	Builds the bazaar map (floor, spawn, stalls) and owns station proximity.

	ProximityPrompt.Triggered fires on the server and the engine already
	enforces MaxActivationDistance, so it is safe to open panels from it.
	For gameplay actions the server re-checks distance itself (IsNear),
	because remotes can be fired from anywhere by an exploiter.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local SyncService = require(script.Parent.SyncService)

export type StationKey = "Bazaar" | "Workbench" | "SellCounter"

local WorldService = {}

local STATION_PANELS: { [string]: string } = {
	Bazaar = "Bazaar",
	Workbench = "Inventory",
	SellCounter = "Inventory",
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function buildStation(parent: Instance, key: string, position: Vector3, label: string, color: Color3)
	local model = Instance.new("Model")
	model.Name = key
	model:SetAttribute("Station", key)

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(12, 3, 5),
		Position = Vector3.new(position.X, 2, position.Z),
		Color = Color3.fromRGB(120, 85, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	for _, offset in { -5.5, 5.5 } do
		part({
			Name = "Pole",
			Size = Vector3.new(0.6, 9, 0.6),
			Position = Vector3.new(position.X + offset, 5, position.Z - 2),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	part({
		Name = "Awning",
		Size = Vector3.new(14, 0.6, 8),
		CFrame = CFrame.new(position.X, 9.6, position.Z - 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(10, 2.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.Parent = counter

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.2
	text.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if key == "Bazaar" then "Browse Crates" elseif key == "Workbench" then "Repair Items" else "Sell Items"
	prompt.ObjectText = label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Stations.InteractRadius
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player: Player)
		SyncService.OpenPanel(player, STATION_PANELS[key] or "Inventory")
	end)

	model.PrimaryPart = counter
	model.Parent = parent
end

function WorldService.IsNear(player: Player, key: StationKey): boolean
	if not Config.Stations.RequireProximity then
		return true
	end
	local station = (Config.Stations :: any)[key]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not station or not root or not root:IsA("BasePart") then
		return false
	end
	local radius = Config.Stations.InteractRadius + Config.Stations.ServerLeeway
	return (root.Position - station.Position).Magnitude <= radius
end

function WorldService.Start()
	local existing = Workspace:FindFirstChild("Bazaar")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Bazaar"

	if not Workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Baseplate",
			Size = Vector3.new(256, 1, 256),
			Position = Vector3.new(0, 0, 0),
			Color = Color3.fromRGB(214, 190, 140),
			Material = Enum.Material.Sand,
			Parent = folder,
		})
	end

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(8, 1, 8)
	spawnPad.Position = Vector3.new(0, 0.6, 6)
	spawnPad.Color = Color3.fromRGB(255, 220, 120)
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Duration = 0
	spawnPad.Parent = folder

	local stations = Config.Stations
	buildStation(folder, "Bazaar", stations.Bazaar.Position, stations.Bazaar.Label, stations.Bazaar.Color)
	buildStation(folder, "Workbench", stations.Workbench.Position, stations.Workbench.Label, stations.Workbench.Color)
	buildStation(folder, "SellCounter", stations.SellCounter.Position, stations.SellCounter.Label, stations.SellCounter.Color)

	folder.Parent = Workspace
end

return WorldService
