--!strict
--[[
	InventoryPanel
	Grid of item cards, reconciled by item id (created / updated / removed)
	so scroll position survives syncs. Every button only sends an item id;
	prices shown are the server's numbers.
	Repairing items get a big "🧽 Scrub!" button (tap mini-game).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Upgrades = require(Shared.Upgrades)
local Types = require(Shared.Types)
local Valuation = require(Shared.Valuation)

local Controllers = script.Parent.Parent.Controllers
local Proximity = require(Controllers.Proximity)
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Icons = require(Shared.Icons)
local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local InventoryPanel = {}

type Card = {
	Frame: Frame,
	Stroke: UIStroke,
	Gradient: UIGradient,
	Icon: TextLabel,
	Name: TextLabel,
	Rarity: TextLabel,
	Status: TextLabel,
	Bar: Frame,
	Fill: Frame,
	Action: TextButton,
	Instant: TextButton,
	Sell: TextButton,
}

local function onAction(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item then
		return
	end
	if item.State == "Dirty" then
		if not Proximity.IsNear("Workbench") then
			Toast.Show("error", Locale.T("N_NeedWorkbench"))
			return
		end
		local snapshot = StateController.Current
		if snapshot and snapshot.ActiveRepairs >= snapshot.RepairSlots then
			Toast.Show("error", Locale.T("N_BenchBusy"))
			return
		end
		StateController.Fire("StartRepair", itemId)
	elseif item.State == "Repairing" then
		StateController.Fire("Scrub", itemId)
		SoundController.Play("Scrub")
		Effects.Bubbles(5)
	end
end

local function onSell(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item or item.State == "Repairing" then
		return
	end
	if not Proximity.IsNear("SellCounter") then
		Toast.Show("error", Locale.T("N_NeedCounter"))
		return
	end
	StateController.Fire("SellItem", itemId)
end

local function onInstant(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item or item.State == "Clean" then
		return
	end
	StateController.Fire("RequestInstantRepair", itemId)
end

local function makeCard(itemId: string, parent: Instance): Card
	local frame: Frame = Create.new("Frame", {
		Name = itemId,
		BackgroundColor3 = Theme.Colors.PanelLight,
		Parent = parent,
	}, { Create.Corner(UDim.new(0.08, 0)) })
	local stroke = Create.Stroke(Theme.Colors.Muted, 3)
	stroke.Parent = frame
	local gradient: UIGradient = Create.new("UIGradient", { Color = Theme.Rainbow, Enabled = false, Parent = stroke })

	local icon =
		Create.Label({ Text = "", Size = UDim2.fromScale(1, 0.25), Position = UDim2.fromScale(0, 0.03), MaxTextSize = 64, Parent = frame })
	local name = Create.Label({
		Text = "",
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.29),
		MaxTextSize = 22,
		Parent = frame,
	})
	local rarity = Create.Label({
		Text = "",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromScale(0.9, 0.07),
		Position = UDim2.fromScale(0.05, 0.4),
		MaxTextSize = 18,
		Parent = frame,
	})
	local status = Create.Label({
		Text = "",
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.9, 0.075),
		Position = UDim2.fromScale(0.05, 0.48),
		MaxTextSize = 18,
		Parent = frame,
	})

	local bar: Frame = Create.new("Frame", {
		Size = UDim2.fromScale(0.84, 0.035),
		Position = UDim2.fromScale(0.08, 0.575),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Visible = false,
		Parent = frame,
	}, { Create.Corner(UDim.new(0.5, 0)) })
	local fill: Frame = Create.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Info,
		Parent = bar,
	}, { Create.Corner(UDim.new(0.5, 0)) })

	local action = Create.Button({
		Text = "",
		Size = UDim2.fromScale(0.66, 0.15),
		Position = UDim2.fromScale(0.05, 0.63),
		BackgroundColor3 = Theme.Colors.Info,
		MaxTextSize = 20,
		Parent = frame,
	}, function()
		onAction(itemId)
	end)
	local instant = Create.Button({
		Text = "⚡",
		Size = UDim2.fromScale(0.22, 0.15),
		Position = UDim2.fromScale(0.73, 0.63),
		BackgroundColor3 = Theme.Colors.Accent,
		MaxTextSize = 24,
		Parent = frame,
	}, function()
		onInstant(itemId)
	end)
	local sell = Create.Button({
		Text = "",
		Size = UDim2.fromScale(0.9, 0.15),
		Position = UDim2.fromScale(0.05, 0.81),
		BackgroundColor3 = Theme.Colors.Success,
		MaxTextSize = 20,
		Parent = frame,
	}, function()
		onSell(itemId)
	end)

	return {
		Frame = frame,
		Stroke = stroke,
		Gradient = gradient,
		Icon = icon,
		Name = name,
		Rarity = rarity,
		Status = status,
		Bar = bar,
		Fill = fill,
		Action = action,
		Instant = instant,
		Sell = sell,
	}
end

local function updateCard(card: Card, item: Types.ItemView, order: number, tokens: number, repairBonus: number, wanted: boolean)
	local color = Items.RarityColors[item.Rarity] or Theme.Colors.Muted
	card.Frame.LayoutOrder = order
	card.Stroke.Color = if item.Shiny then Color3.new(1, 1, 1) else color
	card.Stroke.Thickness = if item.Shiny then 4 else 3
	card.Gradient.Enabled = item.Shiny
	Icons.Set(card.Icon, Icons.Lookup("Items", item.TemplateId), item.Icon)
	card.Name.Text = Locale.ItemName(item.TemplateId)
	card.Rarity.Text = (if item.Shiny then Locale.T("Shiny") .. " · " else "") .. string.upper(Locale.RarityName(item.Rarity))
	card.Rarity.TextColor3 = color
	-- Tokens are free to use; Robux is only shown when upsells are enabled.
	card.Instant.Text = if tokens > 0 then "⚡" .. tokens elseif Config.Monetization.ShowUpsells then "⚡R$" else "⚡"

	if item.State == "Dirty" then
		card.Status.Text = if wanted
			then Locale.T("Inv_Wanted", { tostring(Config.Requests.Multiplier) })
			else Locale.T("Inv_Dirty", { Format.Cash(item.CleanValue) })
		card.Bar.Visible = false
		card.Action.Visible = true
		local seconds = math.max(1, Valuation.RepairSeconds(item.Rarity) * (1 - repairBonus))
		card.Action.Text = Locale.T("Inv_Repair", { Format.Duration(seconds) })
		Create.SetButtonEnabled(card.Action, true, Theme.Colors.Info)
		card.Instant.Visible = tokens > 0 or Config.Monetization.ShowUpsells
		card.Sell.Visible = true
		card.Sell.Text = Locale.T("Inv_SellAsIs", { Format.Cash(item.SellValue) })
		Create.SetButtonEnabled(card.Sell, true, Theme.Colors.PanelDark)
	elseif item.State == "Repairing" then
		card.Status.Text = Locale.T("Inv_Repairing", { "" })
		card.Bar.Visible = true
		card.Action.Visible = true
		card.Action.Text = Locale.T("Inv_Scrub")
		Create.SetButtonEnabled(card.Action, true, Theme.Colors.Pink)
		card.Instant.Visible = tokens > 0 or Config.Monetization.ShowUpsells
		card.Sell.Visible = true
		card.Sell.Text = Locale.T("Inv_OnBench")
		Create.SetButtonEnabled(card.Sell, false, Theme.Colors.Success)
	else
		card.Status.Text = if wanted then Locale.T("Inv_Wanted", { tostring(Config.Requests.Multiplier) }) else Locale.T("Inv_Clean")
		card.Bar.Visible = false
		card.Action.Visible = false
		card.Instant.Visible = false
		card.Sell.Visible = true
		card.Sell.Text = Locale.T("Inv_Sell", { Format.Cash(item.SellValue) })
		Create.SetButtonEnabled(card.Sell, true, Theme.Colors.Success)
	end
end

function InventoryPanel.Build(gui: ScreenGui)
	local cards: { [string]: Card } = {}

	local panel, header, close = Create.Panel("Inventory", Locale.T("Title_Inventory", { "0", "0" }), Theme.Colors.Info, 1.55, gui)
	close.Activated:Connect(UIController.Close)

	Create.Button({
		Text = Locale.T("Inv_SellAll"),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.9, 0.5),
		Size = UDim2.fromScale(0.26, 0.7),
		BackgroundColor3 = Theme.Colors.Success,
		Parent = header,
	}, function()
		if not Proximity.IsNear("SellCounter") then
			Toast.Show("error", Locale.T("N_NeedCounter"))
			return
		end
		StateController.Fire("SellAllClean")
	end)

	local hint = Create.Label({
		Text = "",
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.7, 0.05),
		Position = UDim2.fromScale(0.03, 0.145),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = panel,
	})
	local upgrade = Create.Button({
		Text = Locale.T("Inv_Upgrade"),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.14),
		Size = UDim2.fromScale(0.2, 0.06),
		BackgroundColor3 = Theme.Colors.Robux,
		MaxTextSize = 20,
		Visible = false,
		Parent = panel,
	}, function()
		UIController.Open("CashShop")
	end)

	local scroller: ScrollingFrame = Create.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromScale(0.03, 0.22),
		Size = UDim2.fromScale(0.94, 0.75),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	local grid: UIGridLayout = Create.new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = scroller,
	})
	local function resizeGrid()
		local width = scroller.AbsoluteSize.X - scroller.ScrollBarThickness
		local cell = math.floor(width * 0.235)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.4))
		grid.CellPadding = UDim2.fromOffset(math.floor(width * 0.015), math.floor(width * 0.015))
	end
	UIController.Track(scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid))
	resizeGrid()

	local empty = Create.Label({
		Text = Locale.T("Inv_Empty"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.8, 0.2),
		Position = UDim2.fromScale(0.1, 0.45),
		Visible = false,
		MaxTextSize = 30,
		Parent = panel,
	})

	local function render(snapshot: Types.Snapshot)
		local titleLabel = header:FindFirstChild("Title") :: TextLabel?
		if titleLabel then
			titleLabel.Text = Locale.T("Title_Inventory", { tostring(#snapshot.Items), tostring(snapshot.Capacity) })
		end
		hint.Text = Locale.T("Inv_Hint", { tostring(snapshot.InstantRepairTokens) })
		upgrade.Visible = Config.Monetization.ShowUpsells and not snapshot.Passes.ExtraCapacity
		empty.Visible = #snapshot.Items == 0

		local seen: { [string]: boolean } = {}
		for index, item in snapshot.Items do
			seen[item.Id] = true
			local card = cards[item.Id]
			if not card then
				card = makeCard(item.Id, scroller)
				cards[item.Id] = card
			end
			local request = snapshot.Request
			local wanted = request.TemplateId == item.TemplateId and request.ExpiresAt > StateController.ServerNow()
			local repairBonus = 1
				- (1 - (snapshot.PetBonuses.Repair or 0)) * (1 - Upgrades.Effect("RepairSpeed", snapshot.Upgrades.RepairSpeed or 0))
			repairBonus = math.min(repairBonus, Config.Upgrades.MaxRepairReduction)
			updateCard(card, item, index, snapshot.InstantRepairTokens, repairBonus, wanted)
		end
		for id, card in cards do
			if not seen[id] then
				card.Frame:Destroy()
				cards[id] = nil
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	local accumulator = 0
	local rotation = 0
	UIController.Track(RunService.RenderStepped:Connect(function(dt: number)
		if not panel.Visible then
			return
		end
		rotation = (rotation + dt * 90) % 360
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local snapshot = StateController.Current
		if not snapshot then
			return
		end
		local now = StateController.ServerNow()
		for _, item in snapshot.Items do
			local card = cards[item.Id]
			if card then
				if item.Shiny then
					card.Gradient.Rotation = rotation
				end
				if item.State == "Repairing" and item.RepairStartedAt and item.RepairEndsAt then
					local total = math.max(item.RepairEndsAt - item.RepairStartedAt, 1)
					local alpha = math.clamp((now - item.RepairStartedAt) / total, 0, 1)
					card.Fill.Size = UDim2.fromScale(alpha, 1)
					local left = item.RepairEndsAt - now
					card.Status.Text = if left > 0 then Locale.T("Inv_Repairing", { Format.Duration(left) }) else Locale.T("Inv_Finishing")
				end
			end
		end
	end))

	UIController.Register({ Name = "Inventory", Frame = panel })
end

return InventoryPanel
