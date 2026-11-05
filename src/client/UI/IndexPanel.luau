--!strict
--[[
	IndexPanel
	The collection book: every item in the game, grouped by rarity.
	Undiscovered items show as "❓". Completing a rarity unlocks a reward.
	Shiny versions you have found get a rainbow frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local IndexPanel = {}

type Tile = { TemplateId: string, Icon: TextLabel, Name: TextLabel, Stroke: UIStroke, Gradient: UIGradient }
type Section = { Rarity: Types.Rarity, Title: TextLabel, Claim: TextButton, Grid: UIGridLayout, Tiles: { Tile } }

function IndexPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("Index", Locale.T("Title_Index"), Theme.Colors.VIP, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	local shinyLabel = Create.Label({
		Text = "",
		TextColor3 = Theme.Colors.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.6, 0.05),
		Position = UDim2.fromScale(0.03, 0.145),
		MaxTextSize = 22,
		Parent = panel,
	})

	local scroller: ScrollingFrame = Create.new("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.21),
		Size = UDim2.fromScale(0.94, 0.76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	}, {
		Create.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})

	local sections: { Section } = {}

	for order, rarity in Items.Rarities do
		local color = Items.RarityColors[rarity]
		local section: Frame = Create.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = scroller,
		}, {
			Create.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		})

		local headerRow: Frame = Create.new("Frame", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = section,
		}, { Create.Corner(UDim.new(0.3, 0)), Create.Stroke(color, 2), Create.Aspect(12) })
		local title = Create.Label({
			Text = "",
			Font = Theme.Fonts.Display,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.45, 0.7),
			Position = UDim2.fromScale(0.02, 0.15),
			MaxTextSize = 28,
			Parent = headerRow,
		})
		Create.Label({
			Text = "🎁 " .. Locale.RewardText((Config.Collection.Rewards :: any)[rarity]),
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Accent,
			Size = UDim2.fromScale(0.28, 0.6),
			Position = UDim2.fromScale(0.47, 0.2),
			MaxTextSize = 20,
			Parent = headerRow,
		})
		local claim = Create.Button({
			Text = Locale.T("Index_FindAll"),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.985, 0.5),
			Size = UDim2.fromScale(0.22, 0.75),
			BackgroundColor3 = Theme.Colors.Success,
			MaxTextSize = 20,
			Parent = headerRow,
		}, function()
			StateController.Fire("ClaimCollection", rarity)
		end)

		local gridHolder: Frame = Create.new("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = section,
		})
		local grid: UIGridLayout = Create.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = gridHolder })

		local tiles: { Tile } = {}
		for tileIndex, template in Items.GetByRarity(rarity) do
			local tile: Frame = Create.new("Frame", {
				LayoutOrder = tileIndex,
				BackgroundColor3 = Theme.Colors.PanelDark,
				Parent = gridHolder,
			}, { Create.Corner(UDim.new(0.12, 0)) })
			local stroke = Create.Stroke(color, 2)
			stroke.Parent = tile
			local gradient: UIGradient = Create.new("UIGradient", { Color = Theme.Rainbow, Enabled = false, Parent = stroke })
			local icon = Create.Label({
				Text = "❓",
				Size = UDim2.fromScale(1, 0.6),
				Position = UDim2.fromScale(0, 0.05),
				MaxTextSize = 48,
				Parent = tile,
			})
			local name = Create.Label({
				Text = "???",
				Font = Theme.Fonts.Regular,
				Size = UDim2.fromScale(0.92, 0.28),
				Position = UDim2.fromScale(0.04, 0.66),
				MaxTextSize = 16,
				Parent = tile,
			})
			table.insert(tiles, { TemplateId = template.Id, Icon = icon, Name = name, Stroke = stroke, Gradient = gradient })
		end

		table.insert(sections, { Rarity = rarity, Title = title, Claim = claim, Grid = grid, Tiles = tiles })
	end

	local function resize()
		local width = scroller.AbsoluteSize.X - 18
		local cell = math.floor(width * 0.118)
		for _, section in sections do
			section.Grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.15))
			section.Grid.CellPadding = UDim2.fromOffset(math.floor(width * 0.008), math.floor(width * 0.008))
		end
	end
	UIController.Track(scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()

	local function render(snapshot: Types.Snapshot)
		local shinies = 0
		for _ in snapshot.ShinyCollection do
			shinies += 1
		end
		shinyLabel.Text = Locale.T("Index_Shinies", { tostring(shinies), tostring(#Items.All()) })

		for _, section in sections do
			local found = 0
			for _, tile in section.Tiles do
				local discovered = snapshot.Collection[tile.TemplateId] == true
				local shiny = snapshot.ShinyCollection[tile.TemplateId] == true
				local template = Items.Get(tile.TemplateId)
				if discovered then
					found += 1
				end
				tile.Icon.Text = if discovered and template then template.Icon else "❓"
				tile.Name.Text = if discovered then Locale.ItemName(tile.TemplateId) else "???"
				tile.Gradient.Enabled = shiny
				tile.Stroke.Color = if shiny then Color3.new(1, 1, 1) else Items.RarityColors[section.Rarity]
			end
			local total = #section.Tiles
			section.Title.Text = Locale.T("Index_Progress", { Locale.RarityName(section.Rarity), tostring(found), tostring(total) })
			if snapshot.CollectionClaims[section.Rarity] then
				section.Claim.Text = Locale.T("Index_Claimed")
				Create.SetButtonEnabled(section.Claim, false, Theme.Colors.Success)
			elseif found >= total then
				section.Claim.Text = Locale.T("Index_Claim", { "🎁" })
				Create.SetButtonEnabled(section.Claim, true, Theme.Colors.Success)
			else
				section.Claim.Text = Locale.T("Index_FindAll")
				Create.SetButtonEnabled(section.Claim, false, Theme.Colors.Success)
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	local rotation = 0
	UIController.Track(RunService.RenderStepped:Connect(function(dt: number)
		if not panel.Visible then
			return
		end
		rotation = (rotation + dt * 90) % 360
		for _, section in sections do
			for _, tile in section.Tiles do
				if tile.Gradient.Enabled then
					tile.Gradient.Rotation = rotation
				end
			end
		end
	end))

	UIController.Register({ Name = "Index", Frame = panel })
end

return IndexPanel
