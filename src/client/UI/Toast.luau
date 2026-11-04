--!strict
--[[
	Toast
	Stacked notifications + the big "crate reveal" popup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Toast = {}

local MAX_TOASTS = 4
local LIFETIME = 3

local container: Frame? = nil
local reveal: Frame? = nil
local revealToken = 0
local order = 0

local KIND_COLORS: { [string]: Color3 } = {
	success = Theme.Colors.Success,
	error = Theme.Colors.Danger,
	info = Theme.Colors.Info,
}

function Toast.Show(kind: string, text: string)
	local parent = container
	if not parent then
		return
	end

	local existing = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	if #existing >= MAX_TOASTS then
		table.sort(existing, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		existing[1]:Destroy()
	end

	order += 1
	local color = KIND_COLORS[kind] or Theme.Colors.Info
	local toast: Frame = Create.new("Frame", {
		Name = "Toast",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.05,
		Parent = parent,
	}, {
		Create.Corner(UDim.new(0.3, 0)),
		Create.Stroke(color, 2),
	})
	local label = Create.Label({
		Text = text,
		Size = UDim2.fromScale(0.92, 0.7),
		Position = UDim2.fromScale(0.04, 0.15),
		TextColor3 = Theme.Colors.Text,
		MaxTextSize = 24,
		Parent = toast,
	})

	task.delay(LIFETIME, function()
		if toast.Parent == nil then
			return
		end
		local info = TweenInfo.new(0.35)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		task.wait(0.36)
		toast:Destroy()
	end)
end

function Toast.Reveal(rarity: string, name: string, icon: string)
	local frame = reveal
	if not frame then
		return
	end
	revealToken += 1
	local token = revealToken
	local color = Items.RarityColors[rarity] or Theme.Colors.Info

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	local iconLabel = frame:FindFirstChild("Icon") :: TextLabel?
	local rarityLabel = frame:FindFirstChild("Rarity") :: TextLabel?
	local nameLabel = frame:FindFirstChild("ItemName") :: TextLabel?
	if iconLabel then
		iconLabel.Text = icon
	end
	if rarityLabel then
		rarityLabel.Text = string.upper(rarity) .. (if rarity == "Legendary" then "!!!" elseif rarity == "Rare" then "!" else "")
		rarityLabel.TextColor3 = color
	end
	if nameLabel then
		nameLabel.Text = name
	end

	local scale = frame:FindFirstChildOfClass("UIScale")
	frame.Visible = true
	if scale then
		scale.Scale = 0.3
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	task.delay(if rarity == "Legendary" then 2.6 else 1.8, function()
		if token == revealToken then
			frame.Visible = false
		end
	end)
end

function Toast.Build(gui: ScreenGui)
	container = Create.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromScale(0.34, 0.26),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	}, {
		Create.List(Enum.FillDirection.Vertical, 0.03),
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(520, 400) }),
	})
	local list = (container :: Frame):FindFirstChildOfClass("UIListLayout")
	if list then
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	end

	reveal = Create.new("Frame", {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.28, 0.32),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, {
		Create.Corner(UDim.new(0.08, 0)),
		Create.Stroke(Theme.Colors.Accent, 4),
		Create.Aspect(1.3),
		Create.new("UIScale", {}),
	})
	Create.Label({
		Name = "Icon",
		Text = "📦",
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.05),
		MaxTextSize = 90,
		Parent = reveal,
	})
	Create.Label({
		Name = "Rarity",
		Text = "",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.52),
		MaxTextSize = 48,
		Parent = reveal,
	})
	Create.Label({
		Name = "ItemName",
		Text = "",
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.75),
		MaxTextSize = 30,
		Parent = reveal,
	})

	Net.Get("Notify").OnClientEvent:Connect(function(kind: unknown, text: unknown)
		if type(kind) ~= "string" or type(text) ~= "string" then
			return
		end
		if kind == "reveal" then
			local rarity, name, icon = string.match(text, "^([^|]*)|([^|]*)|(.*)$")
			if rarity and name and icon then
				Toast.Reveal(rarity, name, icon)
				Toast.Show("success", string.format("You found: %s %s", icon, name))
			end
			return
		end
		Toast.Show(kind, text)
	end)
end

return Toast
