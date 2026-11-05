--!strict
--[[
	Toast
	Stacked notifications, the big "box reveal" popup and the level-up banner.
	Server notifications arrive as (kind, localeKey, args) and are translated
	here with Locale.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)

local Controllers = script.Parent.Parent.Controllers
local SoundController = require(Controllers.SoundController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)

local Toast = {}

local MAX_TOASTS = 4
local LIFETIME = 3.2

local container: Frame? = nil
local reveal: Frame? = nil
local banner: Frame? = nil
local revealToken = 0
local bannerToken = 0
local order = 0

local KIND_COLORS: { [string]: Color3 } = {
	success = Theme.Colors.Success,
	error = Theme.Colors.Danger,
	info = Theme.Colors.Info,
	levelup = Theme.Colors.Accent,
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

	if kind == "error" then
		SoundController.Play("Error")
	end

	order += 1
	local color = KIND_COLORS[kind] or Theme.Colors.Info
	local toast: Frame = Create.new("Frame", {
		Name = "Toast",
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = parent,
	}, {
		Create.Corner(UDim.new(0.35, 0)),
		Create.Stroke(color, 3),
	})
	local label = Create.Label({
		Text = text,
		Size = UDim2.fromScale(0.92, 0.7),
		Position = UDim2.fromScale(0.04, 0.15),
		MaxTextSize = 26,
		Parent = toast,
	})
	local scale = Create.new("UIScale", { Scale = 0.7, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

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

-- iconOverride / nameOverride let pets reuse the same reveal popup.
function Toast.Reveal(rarity: string, templateId: string, shiny: boolean, iconOverride: string?, nameOverride: string?)
	local frame = reveal
	if not frame then
		return
	end
	revealToken += 1
	local token = revealToken
	local color = Items.RarityColors[rarity] or Theme.Colors.Info
	local template = Items.Get(templateId)

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if shiny then Color3.new(1, 1, 1) else color
		local gradient = stroke:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Enabled = shiny
		end
	end
	local iconLabel = frame:FindFirstChild("Icon") :: TextLabel?
	local rarityLabel = frame:FindFirstChild("Rarity") :: TextLabel?
	local nameLabel = frame:FindFirstChild("ItemName") :: TextLabel?
	if iconLabel then
		iconLabel.Text = iconOverride or (if template then template.Icon else "📦")
	end
	if rarityLabel then
		local suffix = if rarity == "Legendary" then "!!!" elseif rarity == "Rare" then "!" else ""
		rarityLabel.Text = (if shiny then Locale.T("Shiny") .. " " else "") .. string.upper(Locale.RarityName(rarity)) .. suffix
		rarityLabel.TextColor3 = color
	end
	if nameLabel then
		nameLabel.Text = nameOverride or Locale.ItemName(templateId)
	end

	SoundController.Play("Reveal")
	if rarity == "Legendary" or shiny then
		Effects.Confetti(60)
	elseif rarity == "Rare" then
		Effects.Confetti(20)
	end

	local scale = frame:FindFirstChildOfClass("UIScale")
	frame.Visible = true
	if scale then
		scale.Scale = 0.2
		frame.Rotation = -8
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	end

	task.delay(if rarity == "Legendary" or shiny then 2.8 else 1.8, function()
		if token == revealToken then
			frame.Visible = false
		end
	end)
end

function Toast.Banner(text: string)
	local frame = banner
	if not frame then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local label = frame:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
	SoundController.Play("LevelUp")
	Effects.Confetti(45)
	frame.Visible = true
	local scale = frame:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.3
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	task.delay(2.6, function()
		if token == bannerToken then
			frame.Visible = false
		end
	end)
end

function Toast.Build(gui: ScreenGui)
	container = Create.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.36, 0.26),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	}, {
		Create.List(Enum.FillDirection.Vertical, 0.03),
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(560, 420) }),
	})
	local list = (container :: Frame):FindFirstChildOfClass("UIListLayout")
	if list then
		list.VerticalAlignment = Enum.VerticalAlignment.Top
	end

	local revealStroke = Create.Stroke(Theme.Colors.Accent, 5)
	Create.new("UIGradient", { Color = Theme.Rainbow, Enabled = false, Parent = revealStroke })
	reveal = Create.new("Frame", {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.3, 0.34),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, {
		Create.Corner(UDim.new(0.1, 0)),
		revealStroke,
		Create.Aspect(1.3),
		Create.new("UIScale", {}),
	})
	Create.Label({
		Name = "Icon",
		Text = "📦",
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.05),
		MaxTextSize = 100,
		ZIndex = 31,
		Parent = reveal,
	})
	Create.Label({
		Name = "Rarity",
		Text = "",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.52),
		MaxTextSize = 48,
		ZIndex = 31,
		Parent = reveal,
	})
	Create.Label({
		Name = "ItemName",
		Text = "",
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.75),
		MaxTextSize = 32,
		ZIndex = 31,
		Parent = reveal,
	})

	banner = Create.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromScale(0.5, 0.12),
		BackgroundColor3 = Theme.Colors.Accent,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	}, {
		Create.Corner(UDim.new(0.4, 0)),
		Create.Stroke(Color3.new(1, 1, 1), 4),
		Create.Aspect(5.5),
		Create.new("UIScale", {}),
	})
	Create.Label({
		Name = "Text",
		Text = "",
		Font = Theme.Fonts.Display,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(0.92, 0.76),
		Position = UDim2.fromScale(0.04, 0.12),
		MaxTextSize = 60,
		ZIndex = 41,
		Parent = banner,
	})

	UIController.Track(Net.Get("Notify").OnClientEvent:Connect(function(kind: unknown, key: unknown, args: unknown)
		if type(kind) ~= "string" or type(key) ~= "string" or kind == "wheel" then
			return -- "wheel" results are animated by WheelPanel
		end
		local argList: { any } = if type(args) == "table" then args :: any else {}
		if kind == "reveal" then
			local rarity, templateId, shiny = argList[1], argList[2], argList[3]
			if type(rarity) == "string" and type(templateId) == "string" then
				Toast.Reveal(rarity, templateId, shiny == "1")
				Toast.Show("success", Locale.T("N_Found", { "@item:" .. templateId }))
			end
			return
		end
		if kind == "petreveal" then
			local def = if type(argList[1]) == "string" then Pets.Get(argList[1]) else nil
			if def then
				local stars = tonumber(argList[2]) or 0
				local starsText = string.rep("⭐", stars)
				Toast.Reveal(def.Rarity, "", stars >= 2, def.Icon .. starsText, Locale.T("Pet_" .. def.Id) .. " " .. starsText)
				Toast.Show("success", Locale.T(key, { "@pet:" .. def.Id }))
			end
			return
		end
		local text = Locale.T(key, argList)
		if kind == "levelup" then
			Toast.Banner(text)
			return
		end
		Toast.Show(kind, text)
	end))
end

return Toast
