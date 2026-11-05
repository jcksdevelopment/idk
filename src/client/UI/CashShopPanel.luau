--!strict
--[[
	CashShopPanel
	Robux shop: developer products (boosts) + game passes.
	Buttons only ask the SERVER to prompt the purchase; granting happens
	exclusively in ProcessReceipt / PromptGamePassPurchaseFinished.
	Prices are fetched live from Roblox. A friendly note reminds kids that
	everything can be earned by playing and to ask a grown-up first.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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

local function buildCard(
	parent: Instance,
	order: number,
	prefix: string,
	key: string,
	display: any,
	wide: boolean,
	accent: Color3
): TextButton
	local card: Frame = Create.new("Frame", {
		LayoutOrder = order,
		Size = if wide then UDim2.fromScale(0.485, 1) else UDim2.fromScale(0.315, 1),
		BackgroundColor3 = Theme.Colors.PanelLight,
		ClipsDescendants = true,
		Parent = parent,
	}, { Create.Corner(UDim.new(0.07, 0)), Create.Stroke(accent, 3) })

	if display.Ribbon ~= "" then
		local ribbon: Frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = if wide then UDim2.fromScale(0.3, 0.2) else UDim2.fromScale(0.56, 0.12),
			BackgroundColor3 = Theme.Colors.Pink,
			Parent = card,
		}, { Create.Corner(UDim.new(0.3, 0)) })
		Create.Label({
			Text = Locale.T(display.Ribbon),
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			MaxTextSize = 18,
			Parent = ribbon,
		})
	end

	local title = Locale.T(prefix .. key .. "_Title")
	local description = Locale.T(prefix .. key .. "_Desc")

	if wide then
		Create.Label({
			Text = display.Icon,
			Size = UDim2.fromScale(0.24, 0.7),
			Position = UDim2.fromScale(0.02, 0.15),
			MaxTextSize = 80,
			Parent = card,
		})
		Create.Label({
			Text = title,
			Font = Theme.Fonts.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.45, 0.24),
			Position = UDim2.fromScale(0.28, 0.12),
			MaxTextSize = 30,
			Parent = card,
		})
		Create.Label({
			Text = description,
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.fromScale(0.45, 0.46),
			Position = UDim2.fromScale(0.28, 0.4),
			MaxTextSize = 20,
			Parent = card,
		})
		return Create.Button({
			Text = "…",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.97, 0.6),
			Size = UDim2.fromScale(0.23, 0.36),
			BackgroundColor3 = Theme.Colors.Robux,
			Parent = card,
		}, function() end)
	end

	Create.Label({
		Text = display.Icon,
		Size = UDim2.fromScale(1, 0.28),
		Position = UDim2.fromScale(0, 0.12),
		MaxTextSize = 80,
		Parent = card,
	})
	Create.Label({
		Text = title,
		Font = Theme.Fonts.Display,
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.05, 0.42),
		MaxTextSize = 30,
		Parent = card,
	})
	Create.Label({
		Text = description,
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.56),
		MaxTextSize = 20,
		Parent = card,
	})
	return Create.Button({
		Text = "…",
		Size = UDim2.fromScale(0.86, 0.15),
		Position = UDim2.fromScale(0.07, 0.8),
		BackgroundColor3 = Theme.Colors.Robux,
		Parent = card,
	}, function() end)
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
	Create.Label({
		Text = Locale.T("Shop_Boosts"),
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 0.05),
		Position = UDim2.fromScale(0.03, 0.2),
		MaxTextSize = 28,
		Parent = panel,
	})
	local productRow: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.255),
		Size = UDim2.fromScale(0.94, 0.37),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.0275) })

	Create.Label({
		Text = Locale.T("Shop_Passes"),
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.VIP,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.6, 0.05),
		Position = UDim2.fromScale(0.03, 0.64),
		MaxTextSize = 28,
		Parent = panel,
	})
	local passRow: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.7),
		Size = UDim2.fromScale(0.94, 0.27),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.03) })

	local entries: { Entry } = {}

	for order, key in sortedKeys(Config.ShopDisplay.DevProducts) do
		local display = (Config.ShopDisplay.DevProducts :: any)[key]
		local button = buildCard(productRow, order, "Product_", key, display, false, Theme.Colors.Accent)
		local entry: Entry = { Key = key, Kind = "Product", Id = (Config.DevProducts :: any)[key] or 0, Button = button, PriceText = "…" }
		button.Activated:Connect(function()
			if entry.Id ~= 0 then
				StateController.Fire("PromptProduct", key)
			end
		end)
		table.insert(entries, entry)
	end

	for order, key in sortedKeys(Config.ShopDisplay.GamePasses) do
		local display = (Config.ShopDisplay.GamePasses :: any)[key]
		local button = buildCard(passRow, order, "Pass_", key, display, true, Theme.Colors.VIP)
		local entry: Entry = { Key = key, Kind = "Pass", Id = (Config.GamePasses :: any)[key] or 0, Button = button, PriceText = "…" }
		button.Activated:Connect(function()
			local snapshot = StateController.Current
			local owned = snapshot and (snapshot.Passes :: any)[key] == true
			if entry.Id ~= 0 and not owned then
				StateController.Fire("PromptGamePass", key)
			end
		end)
		table.insert(entries, entry)
	end

	for _, entry in entries do
		fetchPrice(entry)
	end

	local function render(snapshot: Types.Snapshot)
		for _, entry in entries do
			if entry.Kind == "Pass" and (snapshot.Passes :: any)[entry.Key] == true then
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
