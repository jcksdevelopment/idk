--!strict
--[[
	HUD
	Always-on overlay: cash + level bar, chips (bag, tokens, boost), side nav
	with "something to claim" badges, the tutorial banner and the workbench
	strip. Workbench slots are big tappable buttons: tapping a repairing slot
	scrubs it (the server caps how much that helps).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Upgrades = require(Shared.Upgrades)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Device = require(script.Parent.Device)
local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)

local HUD = {}

type Slot = { Button: TextButton, Label: TextLabel, Fill: Frame, ItemId: string? }

local function hasClaimableQuest(snapshot: Types.Snapshot): boolean
	if snapshot.Daily.CanClaim then
		return true
	end
	local weekly = snapshot.Weekly
	if weekly and not weekly.Claimed and weekly.Progress >= weekly.Goal then
		return true
	end
	for _, quest in snapshot.Quests do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			return true
		end
	end
	return false
end

local function hasClaimableCollection(snapshot: Types.Snapshot): boolean
	for _, rarity in Items.Rarities do
		if not snapshot.CollectionClaims[rarity] then
			local complete = true
			for _, template in Items.GetByRarity(rarity) do
				if not snapshot.Collection[template.Id] then
					complete = false
					break
				end
			end
			if complete then
				return true
			end
		end
	end
	return false
end

function HUD.Build(gui: ScreenGui)
	local root: Frame = Create.new("Frame", {
		Name = "HUD",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	------------------------------------------------------------------
	-- Cash pill + level bar
	------------------------------------------------------------------
	local cashPill: Frame = Create.new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.015),
		Size = UDim2.fromScale(0.26, 0.08),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = root,
	}, {
		Create.Corner(UDim.new(0.5, 0)),
		Create.Stroke(Theme.Colors.Accent, 3),
		Create.Aspect(4.2),
	})
	Create.Label({ Text = "💰", Size = UDim2.fromScale(0.18, 0.8), Position = UDim2.fromScale(0.04, 0.1), Parent = cashPill })
	local cashLabel = Create.Label({
		Text = "$0",
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.72, 0.78),
		Position = UDim2.fromScale(0.23, 0.11),
		MaxTextSize = 46,
		Parent = cashPill,
	})
	local cashScale = Create.new("UIScale", { Parent = cashPill })

	local levelFrame: Frame = Create.new("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.26, 0.035),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = root,
	}, { Create.Corner(UDim.new(0.5, 0)), Create.Stroke(Theme.Colors.XP, 2), Create.Aspect(9.5) })
	local xpFill: Frame = Create.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.XP,
		BackgroundTransparency = 0.25,
		Parent = levelFrame,
	}, { Create.Corner(UDim.new(0.5, 0)) })
	local levelLabel = Create.Label({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.8),
		Position = UDim2.fromScale(0.03, 0.1),
		ZIndex = 2,
		MaxTextSize = 20,
		Parent = levelFrame,
	})

	------------------------------------------------------------------
	-- Chips
	------------------------------------------------------------------
	local chips: Frame = Create.new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.145),
		Size = UDim2.fromScale(0.42, 0.045),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.015) })

	local function chip(name: string, color: Color3, order: number): TextLabel
		local frame: Frame = Create.new("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromScale(0.22, 1),
			BackgroundColor3 = Theme.Colors.PanelDark,
			Parent = chips,
		}, { Create.Corner(UDim.new(0.5, 0)), Create.Stroke(color, 2) })
		return Create.Label({ Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), MaxTextSize = 22, Parent = frame })
	end

	local inventoryChip = chip("Inventory", Theme.Colors.Info, 1)
	local tokenChip = chip("Tokens", Theme.Colors.Accent, 2)
	local boostChip = chip("Boost", Theme.Colors.Success, 3)
	local boostFrame = boostChip.Parent :: Frame
	boostFrame.Size = UDim2.fromScale(0.32, 1)

	------------------------------------------------------------------
	-- Tutorial banner
	------------------------------------------------------------------
	local tutorial: Frame = Create.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.205),
		Size = UDim2.fromScale(0.5, 0.07),
		BackgroundColor3 = Theme.Colors.Accent,
		Visible = false,
		Parent = root,
	}, { Create.Corner(UDim.new(0.4, 0)), Create.Stroke(Color3.new(1, 1, 1), 3), Create.Aspect(8.5) })
	-- Customer request bar (same spot as the tutorial banner; hidden during the tutorial)
	local requestButton = Create.Button({
		Name = "Request",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.205),
		Size = UDim2.fromScale(0.36, 0.055),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Text = "",
		MaxTextSize = 22,
		Visible = false,
		Parent = root,
	}, function()
		UIController.Open("Inventory")
	end)
	local requestStroke = requestButton:FindFirstChildOfClass("UIStroke")
	if requestStroke then
		requestStroke.Color = Theme.Colors.Accent
		requestStroke.Transparency = 0
	end

	local tutorialLabel = Create.Label({
		Text = "",
		TextColor3 = Theme.Colors.PanelDark,
		Size = UDim2.fromScale(0.94, 0.62),
		Position = UDim2.fromScale(0.03, 0.06),
		MaxTextSize = 26,
		Parent = tutorial,
	})
	Create.Label({
		Text = Locale.T("Tut_Prompt"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.PanelDark,
		Size = UDim2.fromScale(0.94, 0.26),
		Position = UDim2.fromScale(0.03, 0.68),
		MaxTextSize = 16,
		Parent = tutorial,
	})
	TweenService:Create(
		tutorial,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromScale(0.5, 0.212) }
	):Play()

	------------------------------------------------------------------
	-- Side navigation
	------------------------------------------------------------------
	local nav: Frame = Create.new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.012, 0.52),
		Size = UDim2.fromScale(0.075, 0.8),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Create.List(Enum.FillDirection.Vertical, 0.012),
		Create.Aspect(0.122),
	})

	local function navButton(order: number, icon: string, labelKey: string, key: string, color: Color3, panel: string): TextButton
		local button = Create.Button({
			Name = panel,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0.111),
			BackgroundColor3 = color,
			Text = icon .. "\n" .. Locale.T(labelKey) .. Device.KeyHint(key),
			MaxTextSize = 22,
			Parent = nav,
		}, function()
			UIController.Toggle(panel)
		end)
		Create.Aspect(1).Parent = button
		return button
	end

	navButton(1, "🎒", "Nav_Bag", "I", Theme.Colors.Info, "Inventory")
	local bazaarButton = navButton(2, "📦", "Nav_Crates", "B", Theme.Colors.Accent, "Bazaar")
	local bazaarBadge = Create.Badge(bazaarButton)
	local questsButton = navButton(3, "📜", "Nav_Quests", "Q", Theme.Colors.Pink, "Rewards")
	local indexButton = navButton(4, "📖", "Nav_Index", "C", Theme.Colors.VIP, "Index")
	local upgradesButton = navButton(5, "🛠️", "Nav_Upgrades", "U", Theme.Colors.Info, "Upgrades")
	local trophiesButton = navButton(6, "🏆", "Nav_Trophies", "T", Theme.Colors.Accent, "Trophies")
	navButton(7, "🛒", "Nav_Shop", "P", Theme.Colors.Robux, "CashShop")
	navButton(8, "⚙️", "Nav_Settings", "", Theme.Colors.PanelLight, "Settings")
	local upgradesBadge = Create.Badge(upgradesButton)
	local questsBadge = Create.Badge(questsButton)
	local indexBadge = Create.Badge(indexButton)
	local trophiesBadge = Create.Badge(trophiesButton)

	------------------------------------------------------------------
	-- Lucky Wheel button (top right) + permanent bonus chip
	------------------------------------------------------------------
	local wheelButton = Create.Button({
		Name = "WheelButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.2),
		Size = UDim2.fromScale(0.085, 0.15),
		BackgroundColor3 = Theme.Colors.Accent,
		Text = "🎡",
		MaxTextSize = 22,
		Parent = root,
	}, function()
		UIController.Toggle("Wheel")
	end)
	Create.Aspect(1).Parent = wheelButton
	local wheelBadge = Create.Badge(wheelButton)
	local wheelScale = wheelButton:FindFirstChildOfClass("UIScale")
	local wheelPulse = if wheelScale
		then TweenService:Create(
			wheelScale,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.1 }
		)
		else nil

	local petsButton = Create.Button({
		Name = "PetsButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.37),
		Size = UDim2.fromScale(0.085, 0.15),
		BackgroundColor3 = Theme.Colors.Pink,
		Text = "🐾\n" .. Locale.T("Nav_Pets") .. Device.KeyHint("F"),
		MaxTextSize = 22,
		Parent = root,
	}, function()
		UIController.Toggle("Pets")
	end)
	Create.Aspect(1).Parent = petsButton

	-- Invite friends (Roblox's own invite dialog; friends in the server give +10% money each)
	local inviteButton = Create.Button({
		Name = "InviteButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.54),
		Size = UDim2.fromScale(0.085, 0.15),
		BackgroundColor3 = Theme.Colors.Info,
		Text = "💌\n" .. Locale.T("HUD_Invite"),
		MaxTextSize = 22,
		Parent = root,
	}, function()
		local player = Players.LocalPlayer
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	end)
	Create.Aspect(1).Parent = inviteButton

	local bonusChip = chip("Bonus", Theme.Colors.VIP, 4)
	local bonusFrame = bonusChip.Parent :: Frame
	bonusFrame.Size = UDim2.fromScale(0.18, 1)

	------------------------------------------------------------------
	-- Workbench strip (tap a slot to scrub!)
	------------------------------------------------------------------
	local bench: Frame = Create.new("Frame", {
		Name = "Workbench",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.975),
		Size = UDim2.fromScale(0.5, 0.1),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = root,
	}, {
		Create.Corner(UDim.new(0.25, 0)),
		Create.Stroke(Theme.Colors.Info, 3),
		Create.Aspect(7.5),
	})
	local benchTitle = Create.Label({
		Text = "",
		Size = UDim2.fromScale(0.2, 0.7),
		Position = UDim2.fromScale(0.02, 0.15),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = bench,
	})
	local slotsFrame: Frame = Create.new("Frame", {
		Name = "Slots",
		Position = UDim2.fromScale(0.23, 0.1),
		Size = UDim2.fromScale(0.6, 0.8),
		BackgroundTransparency = 1,
		Parent = bench,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.02, Enum.HorizontalAlignment.Left) })
	local vipButton = Create.Button({
		Name = "VIP",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.5),
		Size = UDim2.fromScale(0.14, 0.7),
		BackgroundColor3 = Theme.Colors.VIP,
		Text = Locale.T("HUD_Slots"),
		MaxTextSize = 20,
		Visible = false,
		Parent = bench,
	}, function()
		UIController.Open("CashShop")
	end)

	local slots: { Slot } = {}
	local slotItems: { Types.ItemView } = {}
	local lastSlotSignature = ""

	local function rebuildSlots(snapshot: Types.Snapshot)
		table.clear(slotItems)
		for _, item in snapshot.Items do
			if item.State == "Repairing" then
				table.insert(slotItems, item)
			end
		end
		local signature = tostring(snapshot.RepairSlots)
		for _, item in slotItems do
			signature ..= item.Id
		end
		if signature == lastSlotSignature then
			return
		end
		lastSlotSignature = signature

		for _, slot in slots do
			slot.Button:Destroy()
		end
		table.clear(slots)

		local width = 1 / math.max(snapshot.RepairSlots, 1) - 0.02
		for index = 1, snapshot.RepairSlots do
			local item = slotItems[index]
			local itemId = if item then item.Id else nil
			local button = Create.Button({
				LayoutOrder = index,
				Size = UDim2.fromScale(width, 1),
				BackgroundColor3 = Theme.Colors.PanelLight,
				Parent = slotsFrame,
			}, function()
				if itemId then
					StateController.Fire("Scrub", itemId)
					SoundController.Play("Scrub")
					Effects.Bubbles(4)
				else
					UIController.Open("Inventory")
				end
			end)
			local fill: Frame = Create.new("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = if item then Items.RarityColors[item.Rarity] else Theme.Colors.PanelLight,
				BackgroundTransparency = 0.4,
				Parent = button,
			}, { Create.Corner(Theme.CornerSmall) })
			local label = Create.Label({
				Text = if item then item.Icon .. " " .. Locale.ItemName(item.TemplateId) else Locale.T("HUD_EmptySlot"),
				TextColor3 = if item then Theme.Colors.Text else Theme.Colors.Muted,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				MaxTextSize = 18,
				Parent = button,
			})
			table.insert(slots, { Button = button, Label = label, Fill = fill, ItemId = itemId })
		end
	end

	------------------------------------------------------------------
	-- State binding
	------------------------------------------------------------------
	local lastCash: number? = nil

	local function render(snapshot: Types.Snapshot)
		cashLabel.Text = Format.Cash(snapshot.Cash)
		if lastCash and snapshot.Cash > lastCash then
			Effects.Popup("+" .. Format.Cash(snapshot.Cash - lastCash), Theme.Colors.Success, UDim2.fromScale(0.5, 0.11))
			SoundController.Play("Sell")
			cashScale.Scale = 1.15
			TweenService:Create(cashScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastCash = snapshot.Cash

		levelLabel.Text = string.format(
			"⭐ %s  ·  %d / %d XP",
			Locale.T("HUD_Level", { tostring(snapshot.Level) }),
			math.floor(snapshot.XPInLevel),
			math.floor(snapshot.XPNeeded)
		)
		xpFill.Size = UDim2.fromScale(math.clamp(snapshot.XPInLevel / math.max(snapshot.XPNeeded, 1), 0, 1), 1)

		inventoryChip.Text = string.format("🎒 %d/%d", #snapshot.Items, snapshot.Capacity)
		inventoryChip.TextColor3 = if #snapshot.Items >= snapshot.Capacity then Theme.Colors.Danger else Theme.Colors.Text
		tokenChip.Text = string.format("⚡ x%d", snapshot.InstantRepairTokens)
		benchTitle.Text = Locale.T("HUD_Workbench", { tostring(snapshot.ActiveRepairs), tostring(snapshot.RepairSlots) })
		vipButton.Visible = Config.Monetization.ShowUpsells and not snapshot.Passes.VIPAutoCleaner

		questsBadge.Visible = hasClaimableQuest(snapshot)
		bazaarBadge.Visible = snapshot.FreeBoxAvailable
		local cheapest = math.huge
		for _, key in Config.Upgrades.Order do
			cheapest = math.min(cheapest, Upgrades.Cost(key, snapshot.Upgrades[key] or 0) or math.huge)
		end
		upgradesBadge.Visible = snapshot.Cash >= cheapest
		indexBadge.Visible = hasClaimableCollection(snapshot)
		trophiesBadge.Visible = snapshot.Rebirths < Config.Rebirth.MaxRebirths
			and snapshot.Level >= snapshot.RebirthLevel
			and snapshot.Cash >= snapshot.RebirthCash

		local permanent = (1 + snapshot.RebirthBonus) * (1 + snapshot.FriendsBonus) * (1 + snapshot.SocialBonus)
		bonusFrame.Visible = permanent > 1.001
		if bonusFrame.Visible then
			bonusChip.Text = Locale.T("HUD_Bonus", { (string.gsub(string.format("%.2f", permanent), "%.?0+$", "")) })
				.. (if snapshot.FriendsBonus > 0 then " 👫" else "")
				.. (if snapshot.InGroup then " 👥" else "")
				.. (if snapshot.IsPremium then " ⭐" else "")
		end

		local step = snapshot.TutorialStep
		tutorial.Visible = step < Config.Tutorial.DoneStep
		if tutorial.Visible then
			tutorialLabel.Text = Locale.T("Tut_" .. tostring(step))
		end

		rebuildSlots(snapshot)
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	-- Timers
	local accumulator = 0
	UIController.Track(RunService.RenderStepped:Connect(function(dt: number)
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

		local request = snapshot.Request
		requestButton.Visible = not tutorial.Visible
		if request.TemplateId ~= "" and request.ExpiresAt > now then
			local template = Items.Get(request.TemplateId)
			requestButton.Text = Locale.T("HUD_Request", {
				(if template then template.Icon .. " " else "") .. Locale.ItemName(request.TemplateId),
				tostring(Config.Requests.Multiplier),
				Format.Duration(request.ExpiresAt - now),
			})
		else
			requestButton.Text = Locale.T("HUD_RequestNext", { Format.Duration(math.max(request.NextAt - now, 0)) })
		end

		local spinLeft = snapshot.NextSpinAt - now
		local spinReady = spinLeft <= 0
		wheelButton.Text = if spinReady then "🎡\n" .. Locale.T("Wheel_Ready") else "🎡\n" .. Format.Duration(spinLeft)
		wheelBadge.Visible = spinReady
		if wheelPulse then
			if spinReady and wheelPulse.PlaybackState ~= Enum.PlaybackState.Playing then
				wheelPulse:Play()
			elseif not spinReady and wheelPulse.PlaybackState == Enum.PlaybackState.Playing then
				wheelPulse:Cancel()
			end
		end

		local remaining = snapshot.BoostEndsAt - now
		boostFrame.Visible = remaining > 0
		if remaining > 0 then
			boostChip.Text = Locale.T("HUD_Boost", { Format.Duration(remaining) })
		end

		for index, slot in slots do
			local item = slotItems[index]
			if item and item.RepairStartedAt and item.RepairEndsAt then
				local total = math.max(item.RepairEndsAt - item.RepairStartedAt, 1)
				local alpha = math.clamp((now - item.RepairStartedAt) / total, 0, 1)
				slot.Fill.Size = UDim2.fromScale(alpha, 1)
				local left = item.RepairEndsAt - now
				slot.Label.Text = if left > 0
					then string.format("%s %s 🧽", item.Icon, Format.Duration(left))
					else string.format("%s %s", item.Icon, Locale.T("HUD_Done"))
			end
		end
	end))
end

return HUD
