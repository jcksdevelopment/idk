--!strict
--[[
	Loading screen (ReplicatedFirst runs before everything else).
	Replaces Roblox's default loader with a branded one: logo, title, a
	bouncing box and rotating tips in the player's language. Fades out once
	the game and our UI are ready (min. 2.5 s so it never flashes).
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local startedAt = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "BazarLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(36, 40, 70)
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(70, 60, 140), Color3.fromRGB(255, 140, 80))
gradient.Rotation = 90
gradient.Parent = background

local function label(text: string, y: number, height: number, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.8, height)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Parent = background
	return l
end

local logo = label("📦", 0.32, 0.22, Enum.Font.FredokaOne)
local title = label("Bazaar Flip", 0.52, 0.11, Enum.Font.FredokaOne)
local status = label("Loading…", 0.64, 0.05, Enum.Font.GothamBold)
local tip = label("", 0.86, 0.05, Enum.Font.GothamMedium)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.72)
barBack.Size = UDim2.fromScale(0.4, 0.025)
barBack.BackgroundColor3 = Color3.fromRGB(24, 27, 48)
barBack.Parent = background
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0.5, 0)
barCorner.Parent = barBack
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
barFill.Parent = barBack
barCorner:Clone().Parent = barFill

-- Bouncing logo
local bounce = RunService.RenderStepped:Connect(function()
	local t = os.clock() - startedAt
	logo.Position = UDim2.fromScale(0.5, 0.32 + math.sin(t * 4) * 0.015)
	logo.Rotation = math.sin(t * 2) * 6
end)

-- Localize + logo image once shared modules replicate.
local tips = { "", "", "", "" }
task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 15)
	if not shared then
		return
	end
	local ok, Locale = pcall(require, shared:WaitForChild("Locale") :: ModuleScript)
	local okConfig, Config = pcall(require, shared:WaitForChild("Config") :: ModuleScript)
	if ok then
		Locale.SetLanguage("en")
		title.Text = Locale.T("Load_Title")
		status.Text = Locale.T("Load_Loading")
		for i = 1, 4 do
			tips[i] = Locale.T("Load_Tip" .. i)
		end
	end
	if okConfig and Config.Images.Logo ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = Config.Images.Logo
		image.Parent = logo
		logo.Text = ""
	end
end)

task.spawn(function()
	local index = 0
	while gui.Parent do
		index = index % #tips + 1
		tip.Text = tips[index]
		task.wait(2.2)
	end
end)

-- Wait for the game + our main UI, animating the bar meanwhile.
local function progress(alpha: number)
	TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(alpha, 1) }):Play()
end
progress(0.2)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
progress(0.6)
playerGui:WaitForChild("BazarUI", 30)
progress(1)
local remaining = 2.5 - (os.clock() - startedAt)
if remaining > 0 then
	task.wait(remaining)
end

-- Fade out
local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, child in background:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif child:IsA("Frame") then
		TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
	elseif child:IsA("ImageLabel") then
		TweenService:Create(child, fade, { ImageTransparency = 1 }):Play()
	end
end
task.wait(0.65)
bounce:Disconnect()
gui:Destroy()
