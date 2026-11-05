--!strict
--[[
	SettingsPanel
	Sound, music, language (Auto / English / Slovenčina) and tutorial skip.
	Settings are saved on the server with the player's profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)

local SettingsPanel = {}

local LANGUAGE_OPTIONS = {
	{ Value = "auto", Label = "Settings_Auto" },
	{ Value = "en", Label = "English" },
	{ Value = "sk", Label = "Slovenčina" },
}

function SettingsPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Settings", Locale.T("Title_Settings"), Theme.Colors.Info, 1.6, gui)
	if not Device.IsSmallScreen() then
		panel.Size = UDim2.fromScale(0.46, 0.56)
	end
	close.Activated:Connect(UIController.Close)

	local list: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.05, 0.18),
		Size = UDim2.fromScale(0.9, 0.78),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Vertical, 0.035) })

	local function row(order: number, labelKey: string): Frame
		local frame: Frame = Create.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0.165),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = list,
		}, { Create.Corner(UDim.new(0.3, 0)) })
		Create.Label({
			Text = Locale.T(labelKey),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.42, 0.6),
			Position = UDim2.fromScale(0.04, 0.2),
			MaxTextSize = 26,
			Parent = frame,
		})
		return frame
	end

	local function toggle(order: number, labelKey: string, key: string): TextButton
		local frame = row(order, labelKey)
		return Create.Button({
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.97, 0.5),
			Size = UDim2.fromScale(0.25, 0.7),
			Parent = frame,
		}, function()
			local snapshot = StateController.Current
			if snapshot then
				StateController.Fire("SetSetting", key, not (snapshot.Settings :: any)[key])
			end
		end)
	end

	local soundButton = toggle(1, "Settings_Sound", "Sound")
	local musicButton = toggle(2, "Settings_Music", "Music")

	local languageRow = row(3, "Settings_Language")
	local languageButtons: { [string]: TextButton } = {}
	for index, option in LANGUAGE_OPTIONS do
		languageButtons[option.Value] = Create.Button({
			Text = if option.Value == "auto" then Locale.T(option.Label) else option.Label,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.97 - (3 - index) * 0.175, 0.5),
			Size = UDim2.fromScale(0.165, 0.7),
			MaxTextSize = 20,
			Parent = languageRow,
		}, function()
			StateController.Fire("SetSetting", "Language", option.Value)
		end)
	end

	local skipRow = row(4, "Settings_SkipTutorial")
	Create.Button({
		Text = "⏭",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromScale(0.25, 0.7),
		BackgroundColor3 = Theme.Colors.Danger,
		Parent = skipRow,
	}, function()
		StateController.Fire("SkipTutorial")
	end)

	-- Gift codes
	local codeRow = row(5, "Settings_Codes")
	local codeBox: TextBox = Create.new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.7, 0.5),
		Size = UDim2.fromScale(0.26, 0.7),
		BackgroundColor3 = Theme.Colors.PanelDark,
		TextColor3 = Theme.Colors.Text,
		PlaceholderText = Locale.T("Codes_Placeholder"),
		PlaceholderColor3 = Theme.Colors.Muted,
		Text = "",
		ClearTextOnFocus = false,
		TextScaled = true,
		Font = Theme.Fonts.Bold,
		Parent = codeRow,
	}, {
		Create.Corner(Theme.CornerSmall),
		Create.new("UITextSizeConstraint", { MaxTextSize = 22 }),
	})
	local function redeem()
		local code = codeBox.Text
		if #code > 0 and #code <= 24 then
			StateController.Fire("RedeemCode", code)
			codeBox.Text = ""
		end
	end
	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			redeem()
		end
	end)
	Create.Button({
		Text = Locale.T("Codes_Redeem"),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromScale(0.25, 0.7),
		BackgroundColor3 = Theme.Colors.Success,
		Parent = codeRow,
	}, redeem)

	local function render(snapshot: Types.Snapshot)
		local settings = snapshot.Settings
		soundButton.Text = Locale.T(if settings.Sound then "Settings_On" else "Settings_Off")
		soundButton.BackgroundColor3 = if settings.Sound then Theme.Colors.Success else Theme.Colors.Disabled
		musicButton.Text = Locale.T(if settings.Music then "Settings_On" else "Settings_Off")
		musicButton.BackgroundColor3 = if settings.Music then Theme.Colors.Success else Theme.Colors.Disabled
		for value, button in languageButtons do
			button.BackgroundColor3 = if settings.Language == value then Theme.Colors.Accent else Theme.Colors.PanelDark
		end
		skipRow.Visible = snapshot.TutorialStep < Config.Tutorial.DoneStep
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({ Name = "Settings", Frame = panel })
end

return SettingsPanel
