--!strict
--[[
	BazaarPanel
	Crate shop (in-game cash). Shows transparent drop odds per crate.
	Buying sends only the crate key; price, odds and the roll are server-side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local Proximity = require(Controllers.Proximity)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local BazaarPanel = {}

type CrateButton = { Button: TextButton, Price: number }

function BazaarPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Bazaar", "📦 Junk Bazaar", Theme.Colors.Accent, 1.7, gui)
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
	}, { Create.List(Enum.FillDirection.Horizontal, 0.03) })

	local crateKeys: { string } = {}
	for key in Config.Crates do
		table.insert(crateKeys, key)
	end
	table.sort(crateKeys, function(a, b)
		return (Config.Crates :: any)[a].Order < (Config.Crates :: any)[b].Order
	end)

	local buttons: { CrateButton } = {}
	local cardWidth = 1 / math.max(#crateKeys, 1) - 0.03

	for index, key in crateKeys do
		local crate = (Config.Crates :: any)[key]
		local card: Frame = Create.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromScale(cardWidth, 1),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = row,
		}, { Create.Corner(UDim.new(0.06, 0)), Create.Stroke(Theme.Colors.Accent, 2) })

		Create.Label({
			Text = crate.Icon,
			Size = UDim2.fromScale(1, 0.26),
			Position = UDim2.fromScale(0, 0.03),
			MaxTextSize = 80,
			Parent = card,
		})
		Create.Label({
			Text = crate.DisplayName,
			Font = Theme.Fonts.Display,
			Size = UDim2.fromScale(0.9, 0.1),
			Position = UDim2.fromScale(0.05, 0.3),
			MaxTextSize = 30,
			Parent = card,
		})

		local total = 0
		for _, rarity in Items.Rarities do
			total += crate.Weights[rarity] or 0
		end
		for rIndex, rarity in Items.Rarities do
			local chance = if total > 0 then (crate.Weights[rarity] or 0) / total * 100 else 0
			Create.Label({
				Text = string.format("%s  %d%%", rarity, math.floor(chance + 0.5)),
				TextColor3 = Items.RarityColors[rarity],
				Size = UDim2.fromScale(0.8, 0.075),
				Position = UDim2.fromScale(0.1, 0.42 + (rIndex - 1) * 0.085),
				MaxTextSize = 22,
				Parent = card,
			})
		end

		local button = Create.Button({
			Text = "Buy " .. Format.Cash(crate.Price),
			Size = UDim2.fromScale(0.86, 0.16),
			Position = UDim2.fromScale(0.07, 0.8),
			BackgroundColor3 = Theme.Colors.Success,
			Parent = card,
		}, function()
			local snapshot = StateController.Current
			if not Proximity.IsNear("Bazaar") then
				Toast.Show("error", "Walk up to the 📦 Junk Bazaar stall to buy.")
				return
			end
			if snapshot and #snapshot.Items >= snapshot.Capacity then
				Toast.Show("error", "Inventory full! Sell junk or grab +20 Inventory.")
				return
			end
			if snapshot and snapshot.Cash < crate.Price then
				Toast.Show("error", "Not enough cash - sell some items first!")
				return
			end
			StateController.Fire("BuyCrate", key)
		end)
		table.insert(buttons, { Button = button, Price = crate.Price })
	end

	local function render(snapshot: Types.Snapshot)
		for _, entry in buttons do
			Create.SetButtonEnabled(entry.Button, snapshot.Cash >= entry.Price, Theme.Colors.Success)
			entry.Button.Active = true -- still clickable so the player gets feedback
		end
	end

	local function refreshHint()
		local snapshot = StateController.Current
		local cash = if snapshot then Format.Cash(snapshot.Cash) else "$0"
		if Proximity.IsNear("Bazaar") then
			hint.Text = "Cash: " .. cash .. " · Every crate is a gamble. Repair what you find and flip it!"
		else
			hint.Text = "Cash: " .. cash .. " · ⚠ Walk to the orange Junk Bazaar stall to buy crates."
		end
	end

	StateController.Changed:Connect(function(snapshot)
		render(snapshot)
		refreshHint()
	end)

	UIController.Register({
		Name = "Bazaar",
		Frame = panel,
		OnOpen = function()
			refreshHint()
			task.spawn(function()
				while panel.Visible do
					refreshHint()
					task.wait(0.5)
				end
			end)
		end,
	})
end

return BazaarPanel
