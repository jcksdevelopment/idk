--!strict
--[[
	TrophyPanel
	Top: "New Start" (rebirth) card with a two-tap confirmation so kids can't
	reset by accident. Below: every achievement with progress; unlocked
	ones can be worn as an overhead title. All checks happen on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local TrophyPanel = {}

type Row = { Id: string, Frame: Frame, Stroke: UIStroke, Fill: Frame, Count: TextLabel, Button: TextButton, Goal: number, Stat: string }

local function goalFor(def: any): number
	if def.Stat == "Collection" then
		return math.min(def.Goal, #Items.All())
	end
	return def.Goal
end

local function formatStat(stat: string, value: number): string
	if stat == "LifetimeEarned" then
		return Format.Cash(value)
	end
	return Format.Commas(value)
end

function TrophyPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Trophies", Locale.T("Title_Trophies"), Theme.Colors.Accent, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	------------------------------------------------------------------
	-- New Start (rebirth) card
	------------------------------------------------------------------
	local card: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.94, 0.25),
		BackgroundColor3 = Theme.Colors.PanelLight,
		Parent = panel,
	}, { Create.Corner(UDim.new(0.12, 0)), Create.Stroke(Theme.Colors.VIP, 3) })
	Create.Label({
		Text = Locale.T("Rebirth_Header"),
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.VIP,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.6, 0.24),
		Position = UDim2.fromScale(0.03, 0.06),
		MaxTextSize = 30,
		Parent = card,
	})
	local desc = Create.Label({
		Text = "",
		Font = Theme.Fonts.Regular,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.62, 0.36),
		Position = UDim2.fromScale(0.03, 0.32),
		MaxTextSize = 18,
		Parent = card,
	})
	local current = Create.Label({
		Text = "",
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.62, 0.22),
		Position = UDim2.fromScale(0.03, 0.72),
		MaxTextSize = 20,
		Parent = card,
	})
	local need = Create.Label({
		Text = "",
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.3, 0.22),
		Position = UDim2.fromScale(0.67, 0.12),
		MaxTextSize = 18,
		Parent = card,
	})

	local confirmUntil = 0
	local rebirthButton: TextButton
	rebirthButton = Create.Button({
		Text = Locale.T("Rebirth_Button"),
		Size = UDim2.fromScale(0.3, 0.42),
		Position = UDim2.fromScale(0.67, 0.44),
		BackgroundColor3 = Theme.Colors.VIP,
		Parent = card,
	}, function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			rebirthButton.Text = Locale.T("Rebirth_Button")
			StateController.Fire("Rebirth")
			return
		end
		confirmUntil = os.clock() + 3
		rebirthButton.Text = Locale.T("Rebirth_Confirm")
		task.delay(3.1, function()
			if os.clock() >= confirmUntil and rebirthButton.Parent then
				rebirthButton.Text = Locale.T("Rebirth_Button")
			end
		end)
	end)

	------------------------------------------------------------------
	-- Achievements
	------------------------------------------------------------------
	Create.Button({
		Text = "🚫 " .. Locale.T("Trophy_NoTitle"),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.415),
		Size = UDim2.fromScale(0.22, 0.055),
		BackgroundColor3 = Theme.Colors.PanelDark,
		MaxTextSize = 18,
		Parent = panel,
	}, function()
		StateController.Fire("SetTitle", "")
	end)

	local scroller: ScrollingFrame = Create.new("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.48),
		Size = UDim2.fromScale(0.94, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	local grid: UIGridLayout = Create.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller })
	local function resize()
		local width = scroller.AbsoluteSize.X - 12
		grid.CellSize = UDim2.fromOffset(math.floor(width * 0.49), math.floor(width * 0.1))
		grid.CellPadding = UDim2.fromOffset(math.floor(width * 0.015), math.floor(width * 0.012))
	end
	UIController.Track(scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()

	local rows: { Row } = {}
	for order, def in Config.Achievements do
		local stroke = Create.Stroke(Theme.Colors.PanelDark, 2)
		local frame: Frame = Create.new("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = scroller,
		}, { Create.Corner(UDim.new(0.2, 0)), stroke })
		Create.Label({
			Text = def.Icon,
			Size = UDim2.fromScale(0.14, 0.8),
			Position = UDim2.fromScale(0.01, 0.1),
			MaxTextSize = 40,
			Parent = frame,
		})
		Create.Label({
			Text = Locale.T("Ach_" .. def.Id),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.52, 0.36),
			Position = UDim2.fromScale(0.16, 0.06),
			MaxTextSize = 22,
			Parent = frame,
		})
		local goal = goalFor(def)
		local goalText = formatStat(def.Stat, goal)
		Create.Label({
			Text = Locale.T("Stat_" .. def.Stat, { goalText }) .. "  🎁 " .. Locale.RewardText(def.Reward :: any),
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.52, 0.24),
			Position = UDim2.fromScale(0.16, 0.42),
			MaxTextSize = 15,
			Parent = frame,
		})
		local bar: Frame = Create.new("Frame", {
			Size = UDim2.fromScale(0.52, 0.18),
			Position = UDim2.fromScale(0.16, 0.72),
			BackgroundColor3 = Theme.Colors.PanelDark,
			Parent = frame,
		}, { Create.Corner(UDim.new(0.5, 0)) })
		local fill: Frame = Create.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Colors.Accent,
			Parent = bar,
		}, { Create.Corner(UDim.new(0.5, 0)) })
		local count = Create.Label({
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			MaxTextSize = 13,
			Parent = bar,
		})
		local id = def.Id
		local button = Create.Button({
			Text = "🔒",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.98, 0.5),
			Size = UDim2.fromScale(0.28, 0.6),
			BackgroundColor3 = Theme.Colors.Info,
			MaxTextSize = 18,
			Parent = frame,
		}, function()
			StateController.Fire("SetTitle", id)
		end)
		table.insert(
			rows,
			{ Id = id, Frame = frame, Stroke = stroke, Fill = fill, Count = count, Button = button, Goal = goal, Stat = def.Stat }
		)
	end

	local function render(snapshot: Types.Snapshot)
		local bonusPercent = math.floor(Config.Rebirth.MoneyBonusPerRebirth * 100 + 0.5)
		desc.Text = Locale.T("Rebirth_Desc", { Format.Cash(Config.Economy.StartingCash), tostring(bonusPercent) })
		current.Text = Locale.T("Rebirth_Current", { tostring(snapshot.Rebirths), tostring(math.floor(snapshot.RebirthBonus * 100 + 0.5)) })
		if snapshot.Rebirths >= Config.Rebirth.MaxRebirths then
			need.Text = Locale.T("Rebirth_Max")
			Create.SetButtonEnabled(rebirthButton, false, Theme.Colors.VIP)
		else
			need.Text = Locale.T("Rebirth_Need", { tostring(snapshot.RebirthLevel), Format.Cash(snapshot.RebirthCash) })
			local ready = snapshot.Level >= snapshot.RebirthLevel and snapshot.Cash >= snapshot.RebirthCash
			Create.SetButtonEnabled(rebirthButton, ready, Theme.Colors.VIP)
		end

		for _, row in rows do
			local value = snapshot.AchievementProgress[row.Id] or 0
			local unlocked = snapshot.Achievements[row.Id] == true
			row.Fill.Size = UDim2.fromScale(math.clamp(value / math.max(row.Goal, 1), 0, 1), 1)
			row.Count.Text = formatStat(row.Stat, value) .. " / " .. formatStat(row.Stat, row.Goal)
			row.Stroke.Color = if unlocked then Theme.Colors.Accent else Theme.Colors.PanelDark
			if not unlocked then
				row.Button.Text = "🔒"
				Create.SetButtonEnabled(row.Button, false, Theme.Colors.Info)
			elseif snapshot.EquippedTitle == row.Id then
				row.Button.Text = Locale.T("Trophy_Equipped")
				Create.SetButtonEnabled(row.Button, true, Theme.Colors.Success)
			else
				row.Button.Text = Locale.T("Trophy_Equip")
				Create.SetButtonEnabled(row.Button, true, Theme.Colors.Info)
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({ Name = "Trophies", Frame = panel })
end

return TrophyPanel
