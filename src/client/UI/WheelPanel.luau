--!strict
--[[
	WheelPanel
	Free Lucky Wheel (one spin per cooldown, never for Robux). The SERVER
	picks the prize and grants it; this panel only animates the wheel so it
	lands on the prize the server announced.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Locale = require(Shared.Locale)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Device = require(script.Parent.Device)
local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local WheelPanel = {}

local SEGMENT_COLORS = {
	Color3.fromRGB(255, 99, 132),
	Color3.fromRGB(255, 196, 40),
	Color3.fromRGB(70, 200, 120),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(175, 100, 255),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(60, 210, 220),
}

function WheelPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Wheel", Locale.T("Wheel_Title"), Theme.Colors.Accent, 1.05, gui)
	if not Device.IsSmallScreen() then
		panel.Size = UDim2.fromScale(0.5, 0.78)
	end
	close.Activated:Connect(UIController.Close)

	local prizes = Config.Wheel.Prizes
	local count = #prizes

	local wheel: CanvasGroup = Create.new("CanvasGroup", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = panel,
	}, {
		Create.Aspect(1),
		Create.Corner(UDim.new(0.5, 0)),
		Create.Stroke(Theme.Colors.Accent, 6),
	})

	for index, prize in prizes do
		local angle = (index - 1) * 360 / count
		local boundary = angle + 180 / count
		-- Spoke between segments
		local b = math.rad(boundary)
		Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(b) * 0.25, 0.5 - math.cos(b) * 0.25),
			Size = UDim2.fromScale(0.012, 0.5),
			Rotation = boundary,
			BackgroundColor3 = Theme.Colors.PanelLight,
			BorderSizePixel = 0,
			Parent = wheel,
		})
		-- Prize bubble
		local a = math.rad(angle)
		local bubble: Frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(a) * 0.33, 0.5 - math.cos(a) * 0.33),
			Size = UDim2.fromScale(0.24, 0.24),
			Rotation = angle,
			BackgroundColor3 = SEGMENT_COLORS[(index - 1) % #SEGMENT_COLORS + 1],
			Parent = wheel,
		}, { Create.Corner(UDim.new(0.5, 0)), Create.Aspect(1) })
		Create.Label({
			Text = prize.Icon,
			Size = UDim2.fromScale(0.8, 0.5),
			Position = UDim2.fromScale(0.1, 0.08),
			MaxTextSize = 40,
			Parent = bubble,
		})
		Create.Label({
			Text = Locale.RewardText(prize.Reward :: any),
			Size = UDim2.fromScale(0.86, 0.3),
			Position = UDim2.fromScale(0.07, 0.6),
			MaxTextSize = 16,
			Parent = bubble,
		})
	end
	Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = Theme.Colors.Accent,
		Parent = wheel,
	}, { Create.Corner(UDim.new(0.5, 0)), Create.Aspect(1) })

	Create.Label({
		Text = "▼",
		TextColor3 = Theme.Colors.Danger,
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.fromScale(0.1, 0.08),
		ZIndex = 8,
		MaxTextSize = 60,
		Parent = panel,
	})

	local spinButton = Create.Button({
		Text = Locale.T("Wheel_Spin"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.6, 0.09),
		BackgroundColor3 = Theme.Colors.Success,
		MaxTextSize = 32,
		Parent = panel,
	}, function() end)
	Create.Label({
		Text = Locale.T("Wheel_Note"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.925),
		Size = UDim2.fromScale(0.9, 0.05),
		MaxTextSize = 18,
		Parent = panel,
	})

	local spinning = false
	local waiting = false

	local function refresh()
		local snapshot = StateController.Current
		if not snapshot or spinning or waiting then
			return
		end
		local left = snapshot.NextSpinAt - StateController.ServerNow()
		if left <= 0 then
			spinButton.Text = Locale.T("Wheel_Spin")
			Create.SetButtonEnabled(spinButton, true, Theme.Colors.Success)
		else
			spinButton.Text = Locale.T("Wheel_Next", { Format.Duration(left) })
			Create.SetButtonEnabled(spinButton, false, Theme.Colors.Success)
		end
	end

	spinButton.Activated:Connect(function()
		local snapshot = StateController.Current
		if spinning or waiting or not snapshot or snapshot.NextSpinAt > StateController.ServerNow() then
			return
		end
		waiting = true
		spinButton.Text = "…"
		StateController.Fire("SpinWheel")
		task.delay(5, function()
			waiting = false -- server did not answer (e.g. rate limit): allow retry
			refresh()
		end)
	end)

	UIController.Track(Net.Get("Notify").OnClientEvent:Connect(function(kind: unknown, key: unknown, args: unknown)
		if kind ~= "wheel" or type(key) ~= "string" or type(args) ~= "table" then
			return
		end
		local list = args :: { any }
		local index = tonumber(list[1])
		if not index or index < 1 or index > count then
			return
		end
		waiting = false
		spinning = true
		UIController.Open("Wheel")
		Create.SetButtonEnabled(spinButton, false, Theme.Colors.Success)

		local angle = (index - 1) * 360 / count
		local current = wheel.Rotation % 360
		wheel.Rotation = current
		local target = current + 360 * 5 + ((360 - angle) - current) % 360
		local tween = TweenService:Create(wheel, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
		tween:Play()
		task.spawn(function()
			-- Ticking sound while spinning
			for i = 1, 14 do
				SoundController.Play("Scrub")
				task.wait(0.05 + i * 0.02)
			end
		end)
		tween.Completed:Wait()
		spinning = false
		SoundController.Play("LevelUp")
		Effects.Confetti(50)
		Toast.Show("success", Locale.T(key, { list[2] }))
		refresh()
	end))

	UIController.Track(StateController.Changed:Connect(function(_snapshot: Types.Snapshot)
		refresh()
	end))
	refresh()

	UIController.Register({
		Name = "Wheel",
		Frame = panel,
		OnOpen = function()
			task.spawn(function()
				local token = UIController.OpenCount
				while panel.Visible and panel.Parent and UIController.OpenCount == token do
					refresh()
					task.wait(1)
				end
			end)
		end,
	})
end

return WheelPanel
