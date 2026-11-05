--!strict
--[[
	Client bootstrap.
	The client is a VIEW: it renders server snapshots and sends requests.
	Nothing here can grant cash, items, XP or time; the server decides.

	The whole UI is built through UIController.Build so it can be rebuilt
	instantly when the player switches language (Settings / auto-detect).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Controllers = script:WaitForChild("Controllers")
local UI = script:WaitForChild("UI")

local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)
local InputController = require(Controllers.InputController)
local RepairController = require(Controllers.RepairController)
local SoundController = require(Controllers.SoundController)
local GuideController = require(Controllers.GuideController)
local OverheadController = require(Controllers.OverheadController)
local PetController = require(Controllers.PetController)

local Toast = require(UI.Toast)
local Effects = require(UI.Effects)
local HUD = require(UI.HUD)
local InventoryPanel = require(UI.InventoryPanel)
local BazaarPanel = require(UI.BazaarPanel)
local CashShopPanel = require(UI.CashShopPanel)
local RewardsPanel = require(UI.RewardsPanel)
local IndexPanel = require(UI.IndexPanel)
local SettingsPanel = require(UI.SettingsPanel)
local TrophyPanel = require(UI.TrophyPanel)
local WheelPanel = require(UI.WheelPanel)
local PetsPanel = require(UI.PetsPanel)

local player = Players.LocalPlayer

-- Best guess before the first snapshot arrives.
Locale.SetLanguage(Locale.Resolve("auto", player.LocaleId))

local function buildUI(gui: ScreenGui)
	Effects.Build(gui)
	Toast.Build(gui)
	HUD.Build(gui)
	InventoryPanel.Build(gui)
	BazaarPanel.Build(gui)
	RewardsPanel.Build(gui)
	IndexPanel.Build(gui)
	TrophyPanel.Build(gui)
	WheelPanel.Build(gui)
	PetsPanel.Build(gui)
	CashShopPanel.Build(gui)
	SettingsPanel.Build(gui)
end

-- Apply the saved language whenever it changes.
StateController.Changed:Connect(function(snapshot)
	local wanted = Locale.Resolve(snapshot.Settings.Language, player.LocaleId)
	if wanted ~= Locale.GetLanguage() then
		Locale.SetLanguage(wanted)
		UIController.Rebuild()
		GuideController.Localize()
		OverheadController.Refresh()
	end
end)

SoundController.Start()
UIController.Build(buildUI)
UIController.Start()
InputController.Start()
RepairController.Start()
GuideController.Start()
OverheadController.Start()
PetController.Start()
-- Rebuild when the screen size class changes (phone rotated, window resized).
do
	local Device = require(UI.Device)
	local wasSmall = Device.IsSmallScreen()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local isSmall = Device.IsSmallScreen()
			if isSmall ~= wasSmall then
				wasSmall = isSmall
				UIController.Rebuild()
			end
		end)
	end
end

StateController.Start() -- last: snapshots arrive once every view is listening
