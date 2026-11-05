--!strict
--[[
	UIController
	Owns the root ScreenGui, the modal panel stack (one panel at a time) and
	the UI lifecycle. Every UI connection is registered with Track() so the
	whole interface can be rebuilt cleanly (e.g. when the language changes).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

export type Panel = {
	Name: string,
	Frame: Frame,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

local UIController = {}

UIController.Gui = nil :: ScreenGui?
UIController.OpenName = nil :: string?
UIController.PanelChanged = Signal.new() :: Signal.Signal<string?>

local panels: { [string]: Panel } = {}
local tracked: { any } = {}
local builder: ((ScreenGui) -> ())? = nil

-- Register a connection (RBXScriptConnection or Signal connection) that
-- belongs to the current UI build.
function UIController.Track(connection: any): any
	table.insert(tracked, connection)
	return connection
end

function UIController.CreateGui(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BazarUI")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BazarUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	UIController.Gui = gui
	return gui
end

function UIController.Register(panel: Panel)
	panels[panel.Name] = panel
	panel.Frame.Visible = false
end

function UIController.Close()
	local name = UIController.OpenName
	if not name then
		return
	end
	local panel = panels[name]
	UIController.OpenName = nil
	if panel then
		panel.Frame.Visible = false
		if panel.OnClose then
			panel.OnClose()
		end
	end
	UIController.PanelChanged:Fire(nil)
end

function UIController.Open(name: string)
	local panel = panels[name]
	if not panel or UIController.OpenName == name then
		return
	end
	UIController.Close()
	UIController.OpenName = name
	panel.Frame.Visible = true

	local scale = panel.Frame:FindFirstChild("OpenScale")
	if scale and scale:IsA("UIScale") then
		scale.Scale = 0.8
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	if panel.OnOpen then
		panel.OnOpen()
	end
	UIController.PanelChanged:Fire(name)
end

function UIController.Toggle(name: string)
	if UIController.OpenName == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

-- Builds (or rebuilds) the entire interface with the stored builder.
function UIController.Build(build: (ScreenGui) -> ())
	builder = build
	UIController.Rebuild()
end

function UIController.Rebuild()
	local reopen = UIController.OpenName
	UIController.OpenName = nil
	for _, connection in tracked do
		connection:Disconnect()
	end
	table.clear(tracked)
	table.clear(panels)

	local build = builder
	if not build then
		return
	end
	build(UIController.CreateGui())
	if reopen then
		UIController.Open(reopen)
	end
end

function UIController.Start()
	Net.Get("OpenPanel").OnClientEvent:Connect(function(name: unknown)
		if type(name) == "string" then
			UIController.Open(name)
		end
	end)
end

return UIController
