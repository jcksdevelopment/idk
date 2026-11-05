--!strict
--[[
	GuideController
	World-side helpers that are purely cosmetic and local to this client:
	- localizes the stall signs and ProximityPrompt texts,
	- during the tutorial, draws a glowing beam from the player to the next
	  stall plus a bouncing arrow above it, so young players always know
	  where to go next.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Net = require(Shared.Net)

local StateController = require(script.Parent.StateController)

local GuideController = {}

local STATIONS = { "Bazaar", "Workbench", "SellCounter" }
local STEP_TARGET: { [number]: string } = {
	[1] = "Bazaar",
	[2] = "Workbench",
	[3] = "Workbench",
	[4] = "SellCounter",
}

local beam: Beam? = nil
local playerAttachment: Attachment? = nil
local arrow: BillboardGui? = nil

local function getCounter(key: string): BasePart?
	local folder = Workspace:FindFirstChild("Bazaar")
	local model = folder and folder:FindFirstChild(key)
	local counter = model and model:FindFirstChild("Counter")
	if counter and counter:IsA("BasePart") then
		return counter
	end
	return nil
end

function GuideController.Localize()
	for _, key in STATIONS do
		local counter = getCounter(key)
		if counter then
			local label = counter:FindFirstChild("Label")
			local text = label and label:FindFirstChild("Text")
			if text and text:IsA("TextLabel") then
				text.Text = Locale.T("World_" .. key)
			end
			local prompt = counter:FindFirstChild("Prompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.ActionText = Locale.T("Prompt_" .. key)
				prompt.ObjectText = Locale.T("Prompt_Object")
			end
		end
	end
end

local function ensureTargetAttachment(counter: BasePart): Attachment
	local existing = counter:FindFirstChild("GuideTarget")
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GuideTarget"
	attachment.Position = Vector3.new(0, 2, 3)
	attachment.Parent = counter
	return attachment
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GuideSource"
	attachment.Position = Vector3.new(0, -1.5, 0)
	attachment.Parent = root
	playerAttachment = attachment
	if beam then
		beam.Attachment0 = attachment
	end
end

local function update()
	local snapshot = StateController.Current
	local currentBeam = beam
	local currentArrow = arrow
	if not snapshot or not currentBeam or not currentArrow then
		return
	end
	local targetKey = STEP_TARGET[snapshot.TutorialStep]
	local counter = if targetKey then getCounter(targetKey) else nil
	if not counter or snapshot.TutorialStep >= Config.Tutorial.DoneStep then
		currentBeam.Enabled = false
		currentArrow.Enabled = false
		return
	end
	currentBeam.Attachment0 = playerAttachment
	currentBeam.Attachment1 = ensureTargetAttachment(counter)
	currentBeam.Enabled = true
	currentArrow.Adornee = counter
	currentArrow.Enabled = true
end

-- Stall particle bursts announced by the server (WorldService.Burst).
local function burst(stationKey: string, color: Color3, count: number)
	local counter = getCounter(stationKey)
	if not counter then
		return
	end
	local emitter = counter:FindFirstChild("LocalBurst")
	if not emitter then
		local newEmitter = Instance.new("ParticleEmitter")
		newEmitter.Name = "LocalBurst"
		newEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		newEmitter.Rate = 0
		newEmitter.Lifetime = NumberRange.new(0.8, 1.4)
		newEmitter.Speed = NumberRange.new(8, 14)
		newEmitter.SpreadAngle = Vector2.new(60, 60)
		newEmitter.EmissionDirection = Enum.NormalId.Top
		newEmitter.Acceleration = Vector3.new(0, -20, 0)
		newEmitter.Size = NumberSequence.new(0.6, 0)
		newEmitter.LightEmission = 0.8
		newEmitter.Parent = counter
		emitter = newEmitter
	end
	local particles = emitter :: ParticleEmitter
	particles.Color = ColorSequence.new(color)
	particles:Emit(count)
end

function GuideController.Start()
	Net.Get("Notify").OnClientEvent:Connect(function(kind: unknown, key: unknown, args: unknown)
		if kind ~= "burst" or type(key) ~= "string" or type(args) ~= "table" then
			return
		end
		local list = args :: { any }
		local r, g, b, n = tonumber(list[1]), tonumber(list[2]), tonumber(list[3]), tonumber(list[4])
		if r and g and b and n then
			burst(key, Color3.fromRGB(r, g, b), math.clamp(n, 1, 60))
		end
	end)

	local newBeam = Instance.new("Beam")
	newBeam.Name = "TutorialBeam"
	newBeam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 140, 40))
	newBeam.LightEmission = 1
	newBeam.Width0 = 0.8
	newBeam.Width1 = 0.8
	newBeam.FaceCamera = true
	newBeam.Segments = 12
	newBeam.Transparency = NumberSequence.new(0.15, 0.4)
	newBeam.Enabled = false
	newBeam.Parent = Workspace
	beam = newBeam

	local newArrow = Instance.new("BillboardGui")
	newArrow.Name = "TutorialArrow"
	newArrow.ResetOnSpawn = false -- lives in PlayerGui: must survive respawns
	newArrow.Size = UDim2.fromScale(4, 4)
	newArrow.StudsOffset = Vector3.new(0, 14, 0)
	newArrow.AlwaysOnTop = true
	newArrow.LightInfluence = 0
	newArrow.Enabled = false
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.fromScale(1, 1)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "⬇"
	arrowLabel.TextScaled = true
	arrowLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.Parent = newArrow
	newArrow.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	arrow = newArrow
	TweenService:Create(
		newArrow,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 12, 0) }
	):Play()

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		attachToCharacter(character)
		update()
	end)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	StateController.Changed:Connect(update)

	-- The map is built by the server; localize it once it has replicated.
	task.spawn(function()
		local folder = Workspace:WaitForChild("Bazaar", 60)
		if folder then
			for _, key in STATIONS do
				folder:WaitForChild(key, 10)
			end
			GuideController.Localize()
			update()
		end
	end)
end

return GuideController
