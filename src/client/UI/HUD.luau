--!strict
--[[
	HUD
	Always-on overlay: cash, inventory count, boost timer / upsell, side nav,
	and the workbench strip with live repair progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local HUD = {}

type Slot = { Frame: Frame, Label: TextLabel, Fill: Frame }

function HUD.Build(gui: ScreenGui)
	local root: Frame = Create.new("Frame", {
		Name = "HUD",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	------------------------------------------------------------------
	-- Cash pill
	------------------------------------------------------------------
	local cashPill: Frame = Create.new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.24, 0.075),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = root,
	}, {
		Create.Corner(UDim.new(0.5, 0)),
		Create.Stroke(Theme.Colors.Accent, 3),
		Create.Aspect(4.2),
	})
	Create.Label({ Text = "💰", Size = UDim2.fromScale(0.18, 0.8), Position = UDim2.fromScale(0.05, 0.1), Parent = cashPill })
	local cashLabel = Create.Label({
		Text = "$0",
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.72, 0.78),
		Position = UDim2.fromScale(0.24, 0.11),
		MaxTextSize = 44,
		Parent = cashPill,
	})

	------------------------------------------------------------------
	-- Info chips (inventory / tokens / boost)
	------------------------------------------------------------------
	local chips: Frame = Create.new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.105),
		Size = UDim2.fromScale(0.4, 0.045),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.015) })

	local function chip(name: string, color: Color3, order: number): TextLabel
		local frame: Frame = Create.new("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromScale(0.28, 1),
			BackgroundColor3 = Theme.Colors.PanelDark,
			Parent = chips,
		}, { Create.Corner(UDim.new(0.5, 0)), Create.Stroke(color, 2) })
		return Create.Label({ Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), MaxTextSize = 22, Parent = frame })
	end

	local inventoryChip = chip("Inventory", Theme.Colors.Info, 1)
	local tokenChip = chip("Tokens", Theme.Colors.Accent, 2)

	local boostButton = Create.Button({
		Name = "Boost",
		LayoutOrder = 3,
		Size = UDim2.fromScale(0.36, 1),
		BackgroundColor3 = Theme.Colors.Robux,
		Text = "Get 2x Money!",
		MaxTextSize = 22,
		Parent = chips,
	}, function()
		UIController.Open("CashShop")
	end)

	------------------------------------------------------------------
	-- Side navigation
	------------------------------------------------------------------
	local nav: Frame = Create.new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.012, 0.5),
		Size = UDim2.fromScale(0.08, 0.44),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Create.List(Enum.FillDirection.Vertical, 0.04),
		Create.Aspect(0.32),
	})

	local function navButton(order: number, text: string, color: Color3, panel: string): TextButton
		local button = Create.Button({
			Name = panel,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = color,
			Text = text,
			MaxTextSize = 26,
			Parent = nav,
		}, function()
			UIController.Toggle(panel)
		end)
		Create.Aspect(1).Parent = button
		return button
	end

	navButton(1, "🎒\nBag [I]", Theme.Colors.Info, "Inventory")
	navButton(2, "📦\nCrates [B]", Theme.Colors.Accent, "Bazaar")
	local shopButton = navButton(3, "🛒\nSHOP [P]", Theme.Colors.Robux, "CashShop")

	-- Gentle pulse on the shop button to draw the eye without being obnoxious.
	local shopStroke = shopButton:FindFirstChildOfClass("UIStroke")
	if shopStroke then
		shopStroke.Color = Color3.fromRGB(180, 255, 200)
		shopStroke.Transparency = 0
		local pulse = TweenService:Create(
			shopStroke,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 5 }
		)
		pulse:Play()
	end

	------------------------------------------------------------------
	-- Workbench strip
	------------------------------------------------------------------
	local bench: Frame = Create.new("Frame", {
		Name = "Workbench",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.975),
		Size = UDim2.fromScale(0.46, 0.09),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = root,
	}, {
		Create.Corner(UDim.new(0.25, 0)),
		Create.Stroke(Theme.Colors.Info, 2),
		Create.Aspect(7.5),
	})
	local benchTitle = Create.Label({
		Text = "🔧 Workbench",
		Size = UDim2.fromScale(0.22, 0.7),
		Position = UDim2.fromScale(0.02, 0.15),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = bench,
	})
	local slotsFrame: Frame = Create.new("Frame", {
		Name = "Slots",
		Position = UDim2.fromScale(0.25, 0.12),
		Size = UDim2.fromScale(0.56, 0.76),
		BackgroundTransparency = 1,
		Parent = bench,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.02, Enum.HorizontalAlignment.Left) })
	local vipButton = Create.Button({
		Name = "VIP",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.5),
		Size = UDim2.fromScale(0.16, 0.7),
		BackgroundColor3 = Theme.Colors.VIP,
		Text = "+2 Slots",
		MaxTextSize = 20,
		Parent = bench,
	}, function()
		UIController.Open("CashShop")
	end)

	local slots: { Slot } = {}
	local slotItems: { Types.ItemView } = {}

	local function rebuildSlots(snapshot: Types.Snapshot)
		for _, slot in slots do
			slot.Frame:Destroy()
		end
		table.clear(slots)
		table.clear(slotItems)

		for _, item in snapshot.Items do
			if item.State == "Repairing" then
				table.insert(slotItems, item)
			end
		end
		local width = 1 / math.max(snapshot.RepairSlots, 1) - 0.02
		for index = 1, snapshot.RepairSlots do
			local item = slotItems[index]
			local frame: Frame = Create.new("Frame", {
				LayoutOrder = index,
				Size = UDim2.fromScale(width, 1),
				BackgroundColor3 = Theme.Colors.PanelLight,
				Parent = slotsFrame,
			}, { Create.Corner(UDim.new(0.25, 0)) })
			local fill: Frame = Create.new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = if item then Items.RarityColors[item.Rarity] else Theme.Colors.PanelLight,
				BackgroundTransparency = 0.45,
				Parent = frame,
			}, { Create.Corner(UDim.new(0.25, 0)) })
			local label = Create.Label({
				Text = if item then item.Icon .. " " .. item.Name else "Empty slot",
				TextColor3 = if item then Theme.Colors.Text else Theme.Colors.Muted,
				Size = UDim2.fromScale(0.92, 0.7),
				Position = UDim2.fromScale(0.04, 0.15),
				MaxTextSize = 18,
				ZIndex = 2,
				Parent = frame,
			})
			table.insert(slots, { Frame = frame, Label = label, Fill = fill })
		end
	end

	------------------------------------------------------------------
	-- State binding
	------------------------------------------------------------------
	local function render(snapshot: Types.Snapshot)
		cashLabel.Text = Format.Cash(snapshot.Cash)
		inventoryChip.Text = string.format("🎒 %d/%d", #snapshot.Items, snapshot.Capacity)
		inventoryChip.TextColor3 = if #snapshot.Items >= snapshot.Capacity then Theme.Colors.Danger else Theme.Colors.Text
		tokenChip.Text = string.format("⚡ x%d", snapshot.InstantRepairTokens)
		benchTitle.Text = string.format("🔧 Workbench %d/%d", snapshot.ActiveRepairs, snapshot.RepairSlots)
		vipButton.Visible = not snapshot.Passes.VIPAutoCleaner
		rebuildSlots(snapshot)
	end

	StateController.Changed:Connect(render)
	if StateController.Current then
		render(StateController.Current)
	end

	-- Per-frame-ish updates for timers.
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
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

		local remaining = snapshot.BoostEndsAt - now
		if remaining > 0 then
			boostButton.Text = "💰 2x MONEY " .. Format.Duration(remaining)
			boostButton.BackgroundColor3 = Theme.Colors.Success
		else
			boostButton.Text = "Get 2x Money!"
			boostButton.BackgroundColor3 = Theme.Colors.Robux
		end

		for index, slot in slots do
			local item = slotItems[index]
			if item and item.RepairStartedAt and item.RepairEndsAt then
				local total = math.max(item.RepairEndsAt - item.RepairStartedAt, 1)
				local alpha = math.clamp((now - item.RepairStartedAt) / total, 0, 1)
				slot.Fill.Size = UDim2.fromScale(alpha, 1)
				local left = item.RepairEndsAt - now
				slot.Label.Text = if left > 0
					then string.format("%s %s", item.Icon, Format.Duration(left))
					else string.format("%s Done!", item.Icon)
			end
		end
	end)
end

return HUD
