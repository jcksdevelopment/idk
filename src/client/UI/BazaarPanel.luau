--!strict
--[[
	BazaarPanel
	Box shop (in-game cash only, never Robux). Drop odds are always shown.
	Bigger boxes unlock with player level. Buying sends only the box key;
	price, odds, level check and the roll are server-side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local Proximity = require(Controllers.Proximity)
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local BazaarPanel = {}

type CrateButton = { Card: Frame, Event: string?, Button: TextButton, Price: number, UnlockLevel: number, Lock: TextLabel }

function BazaarPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Bazaar", Locale.T("Title_Bazaar"), Theme.Colors.Accent, 1.7, gui)
	close.Activated:Connect(UIController.Close)

	local hint = Create.Label({
		Text = "",
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.94, 0.06),
		Position = UDim2.fromScale(0.03, 0.15),
		MaxTextSize = 22,
		Parent = panel,
	})

	local row: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.24),
		Size = UDim2.fromScale(0.94, 0.72),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.025) })

	local crateKeys: { string } = {}
	-- Event boxes are always built; refresh() shows them only while the SERVER
	-- reports the event as active (snapshot.ActiveEvents), not the device clock.
	for key in Config.Crates do
		table.insert(crateKeys, key)
	end
	table.sort(crateKeys, function(a, b)
		return (Config.Crates :: any)[a].Order < (Config.Crates :: any)[b].Order
	end)

	local buttons: { CrateButton } = {}

	for index, key in crateKeys do
		local crate = (Config.Crates :: any)[key]
		local card: Frame = Create.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromScale(0.3, 1),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Visible = not crate.Event,
			Parent = row,
		}, { Create.Corner(UDim.new(0.06, 0)), Create.Stroke(if crate.Event then Theme.Colors.XP else Theme.Colors.Accent, 3) })
		if crate.Event then
			local ribbon: Frame = Create.new("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.6, 0.08),
				BackgroundColor3 = Theme.Colors.Danger,
				ZIndex = 3,
				Parent = card,
			}, { Create.Corner(UDim.new(0.3, 0)) })
			Create.Label({
				Text = (Config.Events :: any)[crate.Event].Icon .. " " .. Locale.T("Event_Limited"),
				Size = UDim2.fromScale(0.9, 0.8),
				Position = UDim2.fromScale(0.05, 0.1),
				ZIndex = 4,
				MaxTextSize = 16,
				Parent = ribbon,
			})
		end

		Create.Label({
			Text = crate.Icon,
			Size = UDim2.fromScale(1, 0.24),
			Position = UDim2.fromScale(0, 0.03),
			MaxTextSize = 80,
			Parent = card,
		})
		Create.Label({
			Text = Locale.T("Crate_" .. key),
			Font = Theme.Fonts.Display,
			Size = UDim2.fromScale(0.9, 0.1),
			Position = UDim2.fromScale(0.05, 0.28),
			MaxTextSize = 28,
			Parent = card,
		})

		local total = 0
		for _, rarity in Items.Rarities do
			total += crate.Weights[rarity] or 0
		end
		for rIndex, rarity in Items.Rarities do
			local chance = if total > 0 then (crate.Weights[rarity] or 0) / total * 100 else 0
			Create.Label({
				Text = string.format("%s  %d%%", Locale.RarityName(rarity), math.floor(chance + 0.5)),
				TextColor3 = Items.RarityColors[rarity],
				Size = UDim2.fromScale(0.84, 0.07),
				Position = UDim2.fromScale(0.08, 0.4 + (rIndex - 1) * 0.08),
				MaxTextSize = 22,
				Parent = card,
			})
		end
		Create.Label({
			Text = string.format("✨ %d%%", math.floor(Config.Shiny.Chance * 100 + 0.5)),
			TextColor3 = Theme.Colors.Pink,
			Size = UDim2.fromScale(0.84, 0.06),
			Position = UDim2.fromScale(0.08, 0.64),
			MaxTextSize = 18,
			Parent = card,
		})

		local button = Create.Button({
			Text = Locale.T("Bazaar_Buy", { Format.Cash(crate.Price) }),
			Size = UDim2.fromScale(0.86, 0.16),
			Position = UDim2.fromScale(0.07, 0.8),
			BackgroundColor3 = Theme.Colors.Success,
			Parent = card,
		}, function()
			local snapshot = StateController.Current
			if snapshot and snapshot.Level < crate.UnlockLevel then
				Toast.Show("error", Locale.T("N_CrateLocked", { tostring(crate.UnlockLevel) }))
				return
			end
			if not Proximity.IsNear("Bazaar") then
				Toast.Show("error", Locale.T("N_NeedBazaar"))
				return
			end
			if snapshot and #snapshot.Items >= snapshot.Capacity then
				Toast.Show("error", Locale.T("N_InventoryFull"))
				return
			end
			if snapshot and snapshot.Cash < crate.Price then
				Toast.Show("error", Locale.T("N_NotEnoughCash"))
				return
			end
			SoundController.Play("Buy")
			StateController.Fire("BuyCrate", key)
		end)

		local lock = Create.Label({
			Text = Locale.T("Bazaar_Locked", { tostring(crate.UnlockLevel) }),
			Font = Theme.Fonts.Display,
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Theme.Colors.PanelDark,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 6,
			MaxTextSize = 34,
			Parent = card,
		})
		Create.Corner(UDim.new(0.06, 0)).Parent = lock
		table.insert(buttons, {
			Card = card,
			Event = crate.Event,
			Button = button,
			Price = crate.Price,
			UnlockLevel = crate.UnlockLevel,
			Lock = lock,
		})
	end

	local function refresh()
		local snapshot = StateController.Current
		local cash = if snapshot then Format.Cash(snapshot.Cash) else "$0"
		hint.Text = Locale.T(if Proximity.IsNear("Bazaar") then "Bazaar_HintNear" else "Bazaar_HintFar", { cash })
		if snapshot then
			local visibleCount = 0
			for _, entry in buttons do
				local event = entry.Event
				entry.Card.Visible = event == nil or table.find(snapshot.ActiveEvents, event) ~= nil
				if entry.Card.Visible then
					visibleCount += 1
				end
			end
			local width = 1 / math.max(visibleCount, 1) - 0.025
			for _, entry in buttons do
				entry.Card.Size = UDim2.fromScale(width, 1)
				entry.Lock.Visible = snapshot.Level < entry.UnlockLevel
				Create.SetButtonEnabled(entry.Button, snapshot.Cash >= entry.Price, Theme.Colors.Success)
				entry.Button.Active = true -- still clickable so the player gets feedback
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(function(_snapshot: Types.Snapshot)
		refresh()
	end))
	refresh()

	UIController.Register({
		Name = "Bazaar",
		Frame = panel,
		OnOpen = function()
			task.spawn(function()
				local token = UIController.OpenCount
				while panel.Visible and panel.Parent and UIController.OpenCount == token do
					refresh()
					task.wait(0.5)
				end
			end)
		end,
	})
end

return BazaarPanel
