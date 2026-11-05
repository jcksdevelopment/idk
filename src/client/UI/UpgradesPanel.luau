--!strict
--[[
	UpgradesPanel
	Permanent workshop upgrades bought with in-game cash. Shows current and
	next effect, level progress and price. The server re-checks everything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Upgrades)

local Controllers = script.Parent.Parent.Controllers
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local UpgradesPanel = {}

type Row = { Key: string, Level: TextLabel, Effect: TextLabel, Fill: Frame, Buy: TextButton }

local function effectText(key: string, value: number): string
	local shown: string
	if key == "Backpack" or key == "Workbench" then
		shown = tostring(math.floor(value + 0.5))
	elseif key == "Luck" then
		shown = string.format("%.1f", value * 100)
	else
		shown = tostring(math.floor(value * 100 + 0.5))
	end
	return Locale.T("Upg_" .. key .. "_Desc", { shown })
end

function UpgradesPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Upgrades", Locale.T("Title_Upgrades"), Theme.Colors.Accent, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	Create.Label({
		Text = "♾️ " .. Locale.T("Upg_Note"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.94, 0.05),
		Position = UDim2.fromScale(0.03, 0.145),
		MaxTextSize = 20,
		Parent = panel,
	})

	local list: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.21),
		Size = UDim2.fromScale(0.94, 0.76),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Vertical, 0.02) })

	local rows: { Row } = {}
	for order, key in Config.Upgrades.Order do
		local def = Upgrades.Def(key)
		if def then
			local row: Frame = Create.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.fromScale(1, 0.18),
				BackgroundColor3 = Theme.Colors.PanelLight,
				Parent = list,
			}, { Create.Corner(UDim.new(0.25, 0)), Create.Stroke(Theme.Colors.PanelDark, 2) })
			Create.Label({
				Text = def.Icon,
				Size = UDim2.fromScale(0.1, 0.8),
				Position = UDim2.fromScale(0.01, 0.1),
				MaxTextSize = 44,
				Parent = row,
			})
			Create.Label({
				Text = Locale.T("Upg_" .. key),
				Font = Theme.Fonts.Display,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.fromScale(0.36, 0.42),
				Position = UDim2.fromScale(0.12, 0.06),
				MaxTextSize = 26,
				Parent = row,
			})
			local effect = Create.Label({
				Text = "",
				Font = Theme.Fonts.Regular,
				TextColor3 = Theme.Colors.Accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.fromScale(0.5, 0.36),
				Position = UDim2.fromScale(0.12, 0.52),
				MaxTextSize = 18,
				Parent = row,
			})
			local bar: Frame = Create.new("Frame", {
				Size = UDim2.fromScale(0.18, 0.3),
				Position = UDim2.fromScale(0.5, 0.12),
				BackgroundColor3 = Theme.Colors.PanelDark,
				Parent = row,
			}, { Create.Corner(UDim.new(0.5, 0)) })
			local fill: Frame = Create.new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Colors.Accent,
				Parent = bar,
			}, { Create.Corner(UDim.new(0.5, 0)) })
			local level = Create.Label({ Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 2, MaxTextSize = 15, Parent = bar })
			local buy = Create.Button({
				Text = "",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(0.985, 0.5),
				Size = UDim2.fromScale(0.28, 0.72),
				BackgroundColor3 = Theme.Colors.Success,
				MaxTextSize = 22,
				Parent = row,
			}, function()
				local snapshot = StateController.Current
				if not snapshot then
					return
				end
				local cost = Upgrades.Cost(key, snapshot.Upgrades[key] or 0)
				if not cost then
					return
				end
				if snapshot.Cash < cost then
					Toast.Show("error", Locale.T("N_NotEnoughCash"))
					return
				end
				SoundController.Play("Buy")
				StateController.Fire("BuyUpgrade", key)
			end)
			table.insert(rows, { Key = key, Level = level, Effect = effect, Fill = fill, Buy = buy })
		end
	end

	local function render(snapshot: Types.Snapshot)
		for _, row in rows do
			local def = Upgrades.Def(row.Key)
			if def then
				local current = snapshot.Upgrades[row.Key] or 0
				local cost = Upgrades.Cost(row.Key, current)
				row.Level.Text = Locale.T("Upg_Level", { tostring(current), tostring(def.MaxLevel) })
				row.Fill.Size = UDim2.fromScale(current / def.MaxLevel, 1)
				if cost then
					row.Effect.Text = Locale.T("Upg_Next", {
						effectText(row.Key, Upgrades.Effect(row.Key, current)),
						effectText(row.Key, Upgrades.Effect(row.Key, current + 1)),
					})
					row.Buy.Text = Locale.T("Upg_Buy", { Format.Cash(cost) })
					Create.SetButtonEnabled(row.Buy, snapshot.Cash >= cost, Theme.Colors.Success)
					row.Buy.Active = true
				else
					row.Effect.Text = effectText(row.Key, Upgrades.Effect(row.Key, current))
					row.Buy.Text = Locale.T("Upg_Max")
					Create.SetButtonEnabled(row.Buy, false, Theme.Colors.Success)
				end
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({ Name = "Upgrades", Frame = panel })
end

return UpgradesPanel
