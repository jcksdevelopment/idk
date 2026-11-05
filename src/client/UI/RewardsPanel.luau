--!strict
--[[
	RewardsPanel
	7-day login gift calendar + today's three quests. Claim buttons just ask
	the server; eligibility is decided (and double-claims are blocked) there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local RewardsPanel = {}

type DayCard = { Frame: Frame, Stroke: UIStroke, Check: TextLabel }
type QuestRow = { Frame: Frame, Title: TextLabel, Reward: TextLabel, Fill: Frame, Count: TextLabel, Claim: TextButton }

local function questTitle(quest: Types.QuestView): string
	local goal = if quest.Id == "EarnCash" then Format.Cash(quest.Goal) else tostring(quest.Goal)
	return Locale.T("Quest_" .. quest.Id, { goal })
end

function RewardsPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Rewards", Locale.T("Title_Rewards"), Theme.Colors.Pink, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	------------------------------------------------------------------
	-- Daily gift calendar
	------------------------------------------------------------------
	Create.Label({
		Text = Locale.T("Rewards_Daily"),
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 0.06),
		Position = UDim2.fromScale(0.03, 0.15),
		MaxTextSize = 30,
		Parent = panel,
	})
	local dailyButton = Create.Button({
		Text = Locale.T("Rewards_Claim"),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.145),
		Size = UDim2.fromScale(0.3, 0.07),
		BackgroundColor3 = Theme.Colors.Success,
		Parent = panel,
	}, function()
		StateController.Fire("ClaimDaily")
	end)

	local dayRow: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.235),
		Size = UDim2.fromScale(0.94, 0.2),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.01) })

	local dayCards: { DayCard } = {}
	for day, reward in Config.DailyRewards do
		local isBig = day == #Config.DailyRewards
		local stroke = Create.Stroke(Theme.Colors.PanelLight, 3)
		local card: Frame = Create.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.fromScale(1 / #Config.DailyRewards - 0.0115, 1),
			BackgroundColor3 = if isBig then Theme.Colors.VIP else Theme.Colors.PanelLight,
			Parent = dayRow,
		}, { Create.Corner(UDim.new(0.15, 0)), stroke })
		Create.Label({
			Text = Locale.T("Rewards_Day", { tostring(day) }),
			Size = UDim2.fromScale(0.9, 0.2),
			Position = UDim2.fromScale(0.05, 0.05),
			MaxTextSize = 18,
			Parent = card,
		})
		Create.Label({
			Text = if isBig
				then "🎁"
				elseif (reward.Tokens or 0) > 0 then "⚡"
				elseif (reward.BoostMinutes or 0) > 0 then "💰"
				else "💵",
			Size = UDim2.fromScale(1, 0.35),
			Position = UDim2.fromScale(0, 0.25),
			MaxTextSize = 40,
			Parent = card,
		})
		Create.Label({
			Text = Locale.RewardText(reward :: any),
			Font = Theme.Fonts.Regular,
			TextWrapped = true,
			Size = UDim2.fromScale(0.92, 0.32),
			Position = UDim2.fromScale(0.04, 0.63),
			MaxTextSize = 16,
			Parent = card,
		})
		local check = Create.Label({
			Text = "✓",
			Font = Theme.Fonts.Display,
			TextColor3 = Theme.Colors.Success,
			BackgroundColor3 = Theme.Colors.PanelDark,
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 6,
			MaxTextSize = 60,
			Parent = card,
		})
		Create.Corner(UDim.new(0.15, 0)).Parent = check
		table.insert(dayCards, { Frame = card, Stroke = stroke, Check = check })
	end

	------------------------------------------------------------------
	-- Quests
	------------------------------------------------------------------
	local questsTitle = Create.Label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.94, 0.06),
		Position = UDim2.fromScale(0.03, 0.46),
		MaxTextSize = 30,
		Parent = panel,
	})
	local questList: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.535),
		Size = UDim2.fromScale(0.94, 0.44),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Vertical, 0.04) })

	local rows: { QuestRow } = {}
	for index = 1, Config.Quests.PerDay do
		local row: Frame = Create.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = questList,
		}, { Create.Corner(UDim.new(0.25, 0)) })
		local title = Create.Label({
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.5, 0.42),
			Position = UDim2.fromScale(0.03, 0.08),
			MaxTextSize = 24,
			Parent = row,
		})
		local reward = Create.Label({
			Text = "",
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(0.22, 0.42),
			Position = UDim2.fromScale(0.53, 0.08),
			MaxTextSize = 20,
			Parent = row,
		})
		local bar: Frame = Create.new("Frame", {
			Size = UDim2.fromScale(0.72, 0.28),
			Position = UDim2.fromScale(0.03, 0.6),
			BackgroundColor3 = Theme.Colors.PanelDark,
			Parent = row,
		}, { Create.Corner(UDim.new(0.5, 0)) })
		local fill: Frame = Create.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Colors.Pink,
			Parent = bar,
		}, { Create.Corner(UDim.new(0.5, 0)) })
		local count = Create.Label({
			Text = "",
			Size = UDim2.fromScale(1, 0.9),
			Position = UDim2.fromScale(0, 0.05),
			ZIndex = 2,
			MaxTextSize = 16,
			Parent = bar,
		})
		local claim = Create.Button({
			Text = Locale.T("Rewards_Claim"),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.98, 0.5),
			Size = UDim2.fromScale(0.2, 0.7),
			BackgroundColor3 = Theme.Colors.Success,
			Parent = row,
		}, function()
			StateController.Fire("ClaimQuest", index)
		end)
		table.insert(rows, { Frame = row, Title = title, Reward = reward, Fill = fill, Count = count, Claim = claim })
	end

	------------------------------------------------------------------
	-- Rendering
	------------------------------------------------------------------
	local function renderTimers(snapshot: Types.Snapshot)
		local now = StateController.ServerNow()
		questsTitle.Text = Locale.T("Rewards_Quests", { Format.Duration(snapshot.QuestsResetAt - now) })
		if snapshot.Daily.CanClaim then
			dailyButton.Text = Locale.T("Rewards_Claim")
			Create.SetButtonEnabled(dailyButton, true, Theme.Colors.Success)
		else
			dailyButton.Text = Locale.T("Rewards_ComeBack", { Format.Duration(snapshot.Daily.NextClaimAt - now) })
			Create.SetButtonEnabled(dailyButton, false, Theme.Colors.Success)
		end
	end

	local function render(snapshot: Types.Snapshot)
		for day, card in dayCards do
			card.Check.Visible = day < snapshot.Daily.NextDay
			local isToday = day == snapshot.Daily.NextDay and snapshot.Daily.CanClaim
			card.Stroke.Color = if isToday then Theme.Colors.Accent else Theme.Colors.PanelLight
			card.Stroke.Thickness = if isToday then 5 else 3
		end
		for index, row in rows do
			local quest = snapshot.Quests[index]
			row.Frame.Visible = quest ~= nil
			if quest then
				row.Title.Text = questTitle(quest)
				row.Reward.Text = Locale.RewardText(quest.Reward)
				row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(quest.Goal, 1), 0, 1), 1)
				row.Count.Text = string.format("%s / %s", Format.Commas(quest.Progress), Format.Commas(quest.Goal))
				if quest.Claimed then
					row.Claim.Text = Locale.T("Rewards_Done")
					Create.SetButtonEnabled(row.Claim, false, Theme.Colors.Success)
				else
					row.Claim.Text = Locale.T("Rewards_Claim")
					Create.SetButtonEnabled(row.Claim, quest.Progress >= quest.Goal, Theme.Colors.Success)
				end
			end
		end
		renderTimers(snapshot)
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({
		Name = "Rewards",
		Frame = panel,
		OnOpen = function()
			task.spawn(function()
				while panel.Visible and panel.Parent do
					local snapshot = StateController.Current
					if snapshot then
						renderTimers(snapshot)
					end
					task.wait(1)
				end
			end)
		end,
	})
end

return RewardsPanel
