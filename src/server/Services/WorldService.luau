--!strict
--[[
	WorldService
	Builds the bazaar map (plaza, stalls, decorations, lighting) and owns
	station proximity.

	ProximityPrompt.Triggered fires on the server and the engine already
	enforces MaxActivationDistance, so it is safe to open panels from it.
	For gameplay actions the server re-checks distance itself (IsNear),
	because remotes can be fired from anywhere by an exploiter.

	Station labels and prompt texts are localized on the client.
]]

local Lighting = game:GetService("Lighting")
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

local STATION_TEXT: { [string]: string } = {
	Bazaar = "📦 BAZAAR",
	Workbench = "🔧 WORKBENCH",
	SellCounter = "💰 SELL",
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Shadows = false
	pointLight.Parent = parent
end

local function buildStation(parent: Instance, key: string, position: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = key
	model:SetAttribute("Station", key)

	-- Colourful rug under the stall so kids can spot "where to stand".
	part({
		Name = "Rug",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 22, 22),
		CFrame = CFrame.new(position.X, 0.8, position.Z + 4) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Fabric,
		Transparency = 0.15,
		CanCollide = false,
		Parent = model,
	})

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(12, 3, 5),
		Position = Vector3.new(position.X, 2, position.Z),
		Color = Color3.fromRGB(150, 100, 65),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	part({
		Name = "CounterTop",
		Size = Vector3.new(12.6, 0.4, 5.6),
		Position = Vector3.new(position.X, 3.7, position.Z),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	for _, offset in { -5.5, 5.5 } do
		part({
			Name = "Pole",
			Size = Vector3.new(0.6, 9, 0.6),
			Position = Vector3.new(position.X + offset, 5, position.Z - 2),
			Color = Color3.fromRGB(110, 75, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	-- Striped awning
	for stripe = 0, 6 do
		part({
			Name = "Awning",
			Size = Vector3.new(2, 0.5, 8),
			CFrame = CFrame.new(position.X - 6 + stripe * 2, 9.6, position.Z - 0.5) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = if stripe % 2 == 0 then color else Color3.new(1, 1, 1),
			Material = Enum.Material.Fabric,
			Parent = model,
		})
	end

	local lamp = part({
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		Position = Vector3.new(position.X, 8.4, position.Z),
		Color = Color3.fromRGB(255, 230, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	light(lamp, Color3.fromRGB(255, 220, 160), 22, 1.6)

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 0.8
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Parent = counter

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(12, 2.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 10.5, 0)
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Parent = counter

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = STATION_TEXT[key] or key
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = color:Lerp(Color3.new(0, 0, 0), 0.5)
	text.TextStrokeTransparency = 0
	text.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = STATION_TEXT[key] or key
	prompt.ObjectText = ""
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

local function buildDecorations(parent: Instance)
	local rng = Random.new(42)
	local palette = {
		Color3.fromRGB(255, 99, 132),
		Color3.fromRGB(255, 205, 86),
		Color3.fromRGB(75, 192, 192),
		Color3.fromRGB(54, 162, 235),
		Color3.fromRGB(153, 102, 255),
	}

	-- Plaza tiles
	for x = -3, 3 do
		for z = -4, 2 do
			part({
				Name = "Tile",
				Size = Vector3.new(11.6, 0.2, 11.6),
				Position = Vector3.new(x * 12, 0.6, z * 12),
				Color = if (x + z) % 2 == 0 then Color3.fromRGB(235, 215, 175) else Color3.fromRGB(220, 195, 150),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		end
	end

	-- Fountain in the middle of the plaza
	part({
		Name = "FountainBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 14, 14),
		CFrame = CFrame.new(0, 1, -10) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local water = part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(0, 2.1, -10) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 180, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		Parent = parent,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 225, 255))
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = water

	-- String-light poles around the plaza
	local poles = {}
	for i = 0, 9 do
		local angle = (i / 10) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 46, 0, -10 + math.sin(angle) * 40)
		local pole = part({
			Name = "LightPole",
			Size = Vector3.new(0.5, 12, 0.5),
			Position = position + Vector3.new(0, 6, 0),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		table.insert(poles, pole)
	end
	for i, pole in poles do
		local nextPole = poles[i % #poles + 1]
		local a = pole.Position + Vector3.new(0, 5.8, 0)
		local b = nextPole.Position + Vector3.new(0, 5.8, 0)
		for bulb = 1, 5 do
			local t = bulb / 6
			local sag = math.sin(t * math.pi) * 1.6
			local bulbPart = part({
				Name = "Bulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				Position = a:Lerp(b, t) - Vector3.new(0, sag, 0),
				Color = palette[(i + bulb) % #palette + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = parent,
			})
			if bulb == 3 then
				light(bulbPart, bulbPart.Color, 14, 0.8)
			end
		end
	end

	-- Trees, barrels and crates for a cosy market feel
	for i = 1, 14 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = rng:NextNumber(55, 85)
		local base = Vector3.new(math.cos(angle) * radius, 0, -10 + math.sin(angle) * radius)
		local height = rng:NextNumber(6, 10)
		part({
			Name = "Trunk",
			Size = Vector3.new(1.4, height, 1.4),
			Position = base + Vector3.new(0, height / 2, 0),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(8, 8, 8) * rng:NextNumber(0.9, 1.3),
			Position = base + Vector3.new(0, height + 2, 0),
			Color = Color3.fromRGB(70 + i * 3, 170, 80),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end

	for i = 1, 10 do
		local x = rng:NextNumber(-40, 40)
		local z = rng:NextNumber(-45, 15)
		local nearStation = false
		for _, key in { "Bazaar", "Workbench", "SellCounter" } do
			local station = (Config.Stations :: any)[key]
			if (Vector3.new(x, 0, z) - Vector3.new(station.Position.X, 0, station.Position.Z)).Magnitude < 16 then
				nearStation = true
			end
		end
		if not nearStation and (math.abs(x) > 10 or z > 0) and (Vector3.new(x, 0, z + 10)).Magnitude > 10 then
			local isBarrel = i % 2 == 0
			part({
				Name = if isBarrel then "Barrel" else "Crate",
				Shape = if isBarrel then Enum.PartType.Cylinder else Enum.PartType.Block,
				Size = if isBarrel then Vector3.new(3, 2.4, 2.4) else Vector3.new(2.6, 2.6, 2.6),
				CFrame = CFrame.new(x, 1.9, z)
					* (if isBarrel then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(0, rng:NextNumber(0, 3), 0)),
				Color = if isBarrel then Color3.fromRGB(140, 90, 50) else Color3.fromRGB(190, 150, 95),
				Material = Enum.Material.WoodPlanks,
				Parent = parent,
			})
		end
	end
end

local function setupLighting()
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
		return instance
	end

	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", "BazarAtmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(255, 225, 190)
	atmosphere.Decay = Color3.fromRGB(255, 180, 140)

	local bloom = ensure("BloomEffect", "BazarBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6

	local grading = ensure("ColorCorrectionEffect", "BazarColor") :: ColorCorrectionEffect
	grading.Saturation = 0.18
	grading.Contrast = 0.06
	grading.TintColor = Color3.fromRGB(255, 247, 235)

	local rays = ensure("SunRaysEffect", "BazarSunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6
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
			Size = Vector3.new(320, 1, 320),
			Position = Vector3.new(0, 0, 0),
			Color = Color3.fromRGB(120, 190, 90),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
	end

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(8, 1, 8)
	spawnPad.Position = Vector3.new(0, 0.6, 10)
	spawnPad.Color = Color3.fromRGB(255, 220, 120)
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Duration = 0
	spawnPad.Parent = folder

	buildDecorations(folder)

	local stations = Config.Stations
	buildStation(folder, "Bazaar", stations.Bazaar.Position, stations.Bazaar.Color)
	buildStation(folder, "Workbench", stations.Workbench.Position, stations.Workbench.Color)
	buildStation(folder, "SellCounter", stations.SellCounter.Position, stations.SellCounter.Color)

	folder.Parent = Workspace
	setupLighting()
end

return WorldService
