--!strict
--[[
	CashShopPanel
	Scrollable Robux shop: featured one-time Starter Pack, consumable boosts
	(Developer Products) and permanent Game Passes.

	Buttons only ask the SERVER to prompt a purchase; granting happens only in
	ProcessReceipt / PromptGamePassPurchaseFinished. Prices are fetched live
	from Roblox. Nothing here sells random rewards or in-game cash
	(Roblox paid-random-items policy), and a note reminds kids to ask a
	grown-up.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Icons = require(Shared.Icons)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local CashShopPanel = {}

type Entry = {
	Key: string,
	Kind: "Product" | "Pass",
	Id: number,
	Button: TextButton,
	PriceText: string,
}

local priceCache: { [number]: string } = {}

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (map[a].Order or 0) < (map[b].Order or 0)
	end)
	return keys
end

local function isBlockedCurrency(key: string): boolean
	return (Config.Monetization.CurrencyProducts :: any)[key] == true and not Config.Monetization.SellCurrencyForRobux
end

local function fetchPrice(entry: Entry)
	if entry.Id == 0 then
		entry.PriceText = Locale.T("Shop_Soon")
		return
	end
	if priceCache[entry.Id] then
		entry.PriceText = priceCache[entry.Id]
		return
	end
	task.spawn(function()
		local infoType = if entry.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, entry.Id, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			entry.PriceText = "R$ " .. tostring(info.PriceInRobux)
			priceCache[entry.Id] = entry.PriceText
		else
			entry.PriceText = Locale.T("Shop_Buy")
		end
		if entry.Button.Parent and entry.Button.Text ~= Locale.T("Shop_Owned") then
			entry.Button.Text = entry.PriceText
		end
	end)
end

-- Uniform card used for both boosts and passes.
local function buildCard(parent: Instance, order: number, prefix: string, key: string, display: any, accent: Color3): TextButton
	local card: Frame = Create.new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = Theme.Colors.PanelLight,
		ClipsDescendants = true,
		Parent = parent,
	}, { Create.Corner(UDim.new(0.07, 0)), Create.Stroke(accent, 3) })

	if display.Ribbon ~= "" then
		local ribbon: Frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.62, 0.11),
			BackgroundColor3 = Theme.Colors.Pink,
			ZIndex = 3,
			Parent = card,
		}, { Create.Corner(UDim.new(0.3, 0)) })
		Create.Label({
			Text = Locale.T(display.Ribbon),
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			ZIndex = 4,
			MaxTextSize = 16,
			Parent = ribbon,
		})
	end

	Icons.Apply(
		Create.Label({
			Text = display.Icon,
			Size = UDim2.fromScale(1, 0.27),
			Position = UDim2.fromScale(0, 0.11),
			MaxTextSize = 70,
			Parent = card,
		}),
		"Shop",
		key
	)
	Create.Label({
		Text = Locale.T(prefix .. key .. "_Title"),
		Font = Theme.Fonts.Display,
		Size = UDim2.fromScale(0.92, 0.12),
		Position = UDim2.fromScale(0.04, 0.4),
		MaxTextSize = 26,
		Parent = card,
	})
	Create.Label({
		Text = Locale.T(prefix .. key .. "_Desc"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		Size = UDim2.fromScale(0.9, 0.22),
		Position = UDim2.fromScale(0.05, 0.54),
		MaxTextSize = 17,
		Parent = card,
	})
	return Create.Button({
		Text = "…",
		Size = UDim2.fromScale(0.86, 0.15),
		Position = UDim2.fromScale(0.07, 0.81),
		BackgroundColor3 = Theme.Colors.Robux,
		Parent = card,
	}, function() end)
end

local function sectionTitle(parent: Instance, order: number, text: string, color: Color3): TextLabel
	return Create.Label({
		LayoutOrder = order,
		Text = text,
		Font = Theme.Fonts.Display,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 40),
		MaxTextSize = 30,
		Parent = parent,
	})
end

local function gridHolder(parent: Instance, order: number): (Frame, UIGridLayout)
	local holder: Frame = Create.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local grid: UIGridLayout = Create.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	return holder, grid
end

function CashShopPanel.Build(gui: ScreenGui)
	local panel, _header, close = Create.Panel("CashShop", Locale.T("Title_Shop"), Theme.Colors.Robux, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	Create.Label({
		Text = "💛 " .. Locale.T("Shop_Note"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		Size = UDim2.fromScale(0.94, 0.05),
		Position = UDim2.fromScale(0.03, 0.14),
		MaxTextSize = 18,
		Parent = panel,
	})

	local scroller: ScrollingFrame = Create.new("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.2),
		Size = UDim2.fromScale(0.94, 0.78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	}, {
		Create.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
	})

	local entries: { Entry } = {}

	------------------------------------------------------------------
	-- Featured Starter Pack
	------------------------------------------------------------------
	local starterDisplay = (Config.ShopDisplay.DevProducts :: any).StarterPack
	local featured: Frame = Create.new("Frame", {
		LayoutOrder = 1,
		BackgroundColor3 = Theme.Colors.Accent,
		Parent = scroller,
	}, { Create.Corner(UDim.new(0.15, 0)), Create.Stroke(Color3.new(1, 1, 1), 3) })
	Create.new("UIGradient", {
		Color = ColorSequence.new(Theme.Colors.Accent, Theme.Colors.Pink),
		Rotation = 0,
		Parent = featured,
	})
	Icons.Apply(
		Create.Label({
			Text = starterDisplay.Icon,
			Size = UDim2.fromScale(0.16, 0.8),
			Position = UDim2.fromScale(0.02, 0.1),
			MaxTextSize = 90,
			Parent = featured,
		}),
		"Shop",
		"StarterPack"
	)
	Create.Label({
		Text = Locale.T("Shop_Featured") .. " · " .. Locale.T(starterDisplay.Ribbon),
		Font = Theme.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(0.52, 0.34),
		Position = UDim2.fromScale(0.19, 0.12),
		MaxTextSize = 34,
		Parent = featured,
	})
	Create.Label({
		Text = Locale.T("Product_StarterPack_Desc"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.fromScale(0.52, 0.38),
		Position = UDim2.fromScale(0.19, 0.5),
		MaxTextSize = 20,
		Parent = featured,
	})
	local starterButton = Create.Button({
		Text = "…",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromScale(0.25, 0.5),
		BackgroundColor3 = Theme.Colors.Robux,
		MaxTextSize = 30,
		Parent = featured,
	}, function() end)
	local starterEntry: Entry = {
		Key = "StarterPack",
		Kind = "Product",
		Id = (Config.DevProducts :: any).StarterPack or 0,
		Button = starterButton,
		PriceText = "…",
	}
	starterButton.Activated:Connect(function()
		if starterEntry.Id ~= 0 then
			StateController.Fire("PromptProduct", "StarterPack")
		end
	end)
	table.insert(entries, starterEntry)

	------------------------------------------------------------------
	-- Boosts (developer products) and Game Passes
	------------------------------------------------------------------
	sectionTitle(scroller, 2, Locale.T("Shop_Boosts"), Theme.Colors.Accent)
	local productHolder, productGrid = gridHolder(scroller, 3)
	sectionTitle(scroller, 4, Locale.T("Shop_Passes"), Theme.Colors.VIP)
	local passHolder, passGrid = gridHolder(scroller, 5)

	for order, key in sortedKeys(Config.ShopDisplay.DevProducts) do
		local display = (Config.ShopDisplay.DevProducts :: any)[key]
		if not display.Featured and not isBlockedCurrency(key) then
			local button = buildCard(productHolder, order, "Product_", key, display, Theme.Colors.Accent)
			local entry: Entry =
				{ Key = key, Kind = "Product", Id = (Config.DevProducts :: any)[key] or 0, Button = button, PriceText = "…" }
			button.Activated:Connect(function()
				if entry.Id ~= 0 then
					StateController.Fire("PromptProduct", key)
				end
			end)
			table.insert(entries, entry)
		end
	end

	for order, key in sortedKeys(Config.ShopDisplay.GamePasses) do
		local display = (Config.ShopDisplay.GamePasses :: any)[key]
		local button = buildCard(passHolder, order, "Pass_", key, display, Theme.Colors.VIP)
		local entry: Entry = { Key = key, Kind = "Pass", Id = (Config.GamePasses :: any)[key] or 0, Button = button, PriceText = "…" }
		button.Activated:Connect(function()
			local snapshot = StateController.Current
			local owned = snapshot and snapshot.Passes[key] == true
			if entry.Id ~= 0 and not owned then
				StateController.Fire("PromptGamePass", key)
			end
		end)
		table.insert(entries, entry)
	end

	for _, entry in entries do
		fetchPrice(entry)
	end

	-- Offset sizes derived from the scroller width (3 cards per row).
	local function resize()
		local width = scroller.AbsoluteSize.X - 14
		local gap = 12
		local cell = math.floor((width - gap * 2) / 3)
		for _, grid in { productGrid, passGrid } do
			grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.25))
			grid.CellPadding = UDim2.fromOffset(gap, gap)
		end
		featured.Size = UDim2.fromOffset(width, math.floor(width * 0.19))
	end
	UIController.Track(scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()

	local function render(snapshot: Types.Snapshot)
		featured.Visible = not snapshot.StarterPackBought
		for _, entry in entries do
			if entry.Kind == "Pass" and snapshot.Passes[entry.Key] == true then
				entry.Button.Text = Locale.T("Shop_Owned")
				Create.SetButtonEnabled(entry.Button, false, Theme.Colors.Robux)
			else
				entry.Button.Text = entry.PriceText
				Create.SetButtonEnabled(entry.Button, entry.Id ~= 0, Theme.Colors.Robux)
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({ Name = "CashShop", Frame = panel })
end

return CashShopPanel
