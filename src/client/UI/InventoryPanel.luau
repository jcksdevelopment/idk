--!strict
--[[
	InventoryPanel
	Grid of item cards. Cards are reconciled by item id (created / updated /
	removed) instead of being rebuilt, so hover state and scroll survive syncs.
	Every button only sends an item id; prices shown are the server's numbers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Types = require(Shared.Types)
local Valuation = require(Shared.Valuation)

local Controllers = script.Parent.Parent.Controllers
local Proximity = require(Controllers.Proximity)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local InventoryPanel = {}

type Card = {
	Frame: Frame,
	Stroke: UIStroke,
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

local cards: { [string]: Card } = {}

local function fire(remote: string, itemId: string)
	StateController.Fire(remote, itemId)
end

local function onAction(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item then
		return
	end
	if item.State == "Dirty" then
		if not Proximity.IsNear("Workbench") then
			Toast.Show("error", "Walk to the 🔧 Repair Workbench to start repairs.")
			return
		end
		local snapshot = StateController.Current
		if snapshot and snapshot.ActiveRepairs >= snapshot.RepairSlots then
			Toast.Show(
				"error",
				if snapshot.Passes.VIPAutoCleaner then "All workbench slots are busy." else "Workbench busy! VIP Auto-Cleaner adds 2 slots."
			)
			return
		end
		fire("StartRepair", itemId)
	end
end

local function onSell(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item or item.State == "Repairing" then
		return
	end
	if not Proximity.IsNear("SellCounter") then
		Toast.Show("error", "Walk to the 💰 Sell Counter to sell.")
		return
	end
	fire("SellItem", itemId)
end

local function onInstant(itemId: string)
	local item = StateController.FindItem(itemId)
	if not item or item.State == "Clean" then
		return
	end
	fire("RequestInstantRepair", itemId)
end

local function makeCard(itemId: string, parent: Instance): Card
	local frame: Frame = Create.new("Frame", {
		Name = itemId,
		BackgroundColor3 = Theme.Colors.PanelLight,
		Parent = parent,
	}, { Create.Corner(UDim.new(0.08, 0)) })
	local stroke = Create.Stroke(Theme.Colors.Muted, 3)
	stroke.Parent = frame

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
		BackgroundColor3 = Theme.Colors.Robux,
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

local function updateCard(card: Card, item: Types.ItemView, order: number, tokens: number)
	local color = Items.RarityColors[item.Rarity] or Theme.Colors.Muted
	card.Frame.LayoutOrder = order
	card.Stroke.Color = color
	card.Icon.Text = item.Icon
	card.Name.Text = item.Name
	card.Rarity.Text = string.upper(item.Rarity)
	card.Rarity.TextColor3 = color
	card.Instant.Text = if tokens > 0 then "⚡" .. tokens else "⚡R$"

	if item.State == "Dirty" then
		card.Status.Text = "Dirty · worth " .. Format.Cash(item.CleanValue) .. " clean"
		card.Bar.Visible = false
		card.Action.Visible = true
		card.Action.Text = "🔧 Repair " .. Format.Duration(Valuation.RepairSeconds(item.Rarity))
		Create.SetButtonEnabled(card.Action, true, Theme.Colors.Info)
		card.Instant.Visible = true
		card.Sell.Visible = true
		card.Sell.Text = "Sell as-is " .. Format.Cash(item.SellValue)
		Create.SetButtonEnabled(card.Sell, true, Theme.Colors.PanelDark)
	elseif item.State == "Repairing" then
		card.Status.Text = "Repairing…"
		card.Bar.Visible = true
		card.Action.Visible = true
		Create.SetButtonEnabled(card.Action, false, Theme.Colors.Info)
		card.Instant.Visible = true
		card.Sell.Visible = true
		card.Sell.Text = "On workbench"
		Create.SetButtonEnabled(card.Sell, false, Theme.Colors.Success)
	else
		card.Status.Text = "✨ Clean - ready to flip!"
		card.Bar.Visible = false
		card.Action.Visible = false
		card.Instant.Visible = false
		card.Sell.Visible = true
		card.Sell.Text = "💰 Sell " .. Format.Cash(item.SellValue)
		Create.SetButtonEnabled(card.Sell, true, Theme.Colors.Success)
	end
end

function InventoryPanel.Build(gui: ScreenGui)
	local panel, header, close = Create.Panel("Inventory", "🎒 Inventory", Theme.Colors.Info, 1.55, gui)
	close.Activated:Connect(UIController.Close)

	Create.Button({
		Text = "💰 Sell All Clean",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.9, 0.5),
		Size = UDim2.fromScale(0.24, 0.7),
		BackgroundColor3 = Theme.Colors.Success,
		Parent = header,
	}, function()
		if not Proximity.IsNear("SellCounter") then
			Toast.Show("error", "Walk to the 💰 Sell Counter to sell.")
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
		Text = "🎒 +20 Slots",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.14),
		Size = UDim2.fromScale(0.2, 0.06),
		BackgroundColor3 = Theme.Colors.Robux,
		MaxTextSize = 20,
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
		ScrollBarThickness = 6,
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
	-- Cells are derived from the scroller's width (4 per row), so the grid
	-- scales with screen size while keeping cards proportional.
	local function resizeGrid()
		local width = scroller.AbsoluteSize.X - scroller.ScrollBarThickness
		local cell = math.floor(width * 0.235)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.4))
		grid.CellPadding = UDim2.fromOffset(math.floor(width * 0.015), math.floor(width * 0.015))
	end
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid)
	resizeGrid()

	local empty = Create.Label({
		Text = "Your stall is empty!\nBuy mystery junk at the 📦 Junk Bazaar.",
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.8, 0.2),
		Position = UDim2.fromScale(0.1, 0.45),
		Visible = false,
		MaxTextSize = 28,
		Parent = panel,
	})

	local function render(snapshot: Types.Snapshot)
		local titleLabel = header:FindFirstChild("Title") :: TextLabel?
		if titleLabel then
			titleLabel.Text = string.format("🎒 Inventory %d/%d", #snapshot.Items, snapshot.Capacity)
		end
		hint.Text = string.format(
			"Repair at the 🔧 Workbench · Sell at the 💰 Counter · ⚡ tokens: %d%s",
			snapshot.InstantRepairTokens,
			if snapshot.MoneyMultiplier > 1 then " · 💰 2x ACTIVE" else ""
		)
		upgrade.Visible = not snapshot.Passes.ExtraCapacity
		empty.Visible = #snapshot.Items == 0

		local seen: { [string]: boolean } = {}
		for index, item in snapshot.Items do
			seen[item.Id] = true
			local card = cards[item.Id]
			if not card then
				card = makeCard(item.Id, scroller)
				cards[item.Id] = card
			end
			updateCard(card, item, index, snapshot.InstantRepairTokens)
		end
		for id, card in cards do
			if not seen[id] then
				card.Frame:Destroy()
				cards[id] = nil
			end
		end
	end

	StateController.Changed:Connect(render)
	if StateController.Current then
		render(StateController.Current)
	end

	-- Live repair countdowns while the panel is open.
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not panel.Visible then
			return
		end
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
			if card and item.State == "Repairing" and item.RepairStartedAt and item.RepairEndsAt then
				local total = math.max(item.RepairEndsAt - item.RepairStartedAt, 1)
				local alpha = math.clamp((now - item.RepairStartedAt) / total, 0, 1)
				card.Fill.Size = UDim2.fromScale(alpha, 1)
				local left = item.RepairEndsAt - now
				card.Status.Text = if left > 0 then "Repairing… " .. Format.Duration(left) else "Finishing up…"
				card.Action.Text = if left > 0 then "⏳ " .. Format.Duration(left) else "✔ Done"
			end
		end
	end)

	UIController.Register({ Name = "Inventory", Frame = panel })
end

return InventoryPanel
