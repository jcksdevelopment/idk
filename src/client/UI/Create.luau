--!strict
--[[
	Create
	Minimal declarative instance builder + a few styled primitives.
	All sizes/positions passed in by callers use Scale so the UI adapts to
	phones, tablets, consoles and desktops.
]]

local TweenService = game:GetService("TweenService")

local Device = require(script.Parent.Device)
local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Create = {}

export type Props = { [string]: any }

-- Create.new("Frame", { Size = ..., Parent = ... }, { children })
function Create.new(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Create.Corner(radius: UDim?): UICorner
	return Create.new("UICorner", { CornerRadius = radius or Theme.CornerScale })
end

function Create.Stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return Create.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.Padding(scale: number): UIPadding
	local u = UDim.new(scale, 0)
	return Create.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Create.Aspect(ratio: number): UIAspectRatioConstraint
	return Create.new("UIAspectRatioConstraint", { AspectRatio = ratio })
end

function Create.List(direction: Enum.FillDirection, padding: number, align: Enum.HorizontalAlignment?): UIListLayout
	return Create.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(padding, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function Create.Label(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Bold,
		TextScaled = true,
		RichText = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Create.new("TextLabel", defaults)
	Create.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 36, MinTextSize = 8, Parent = label })
	return label
end

-- A rounded, stroked button with hover/press feedback.
function Create.Button(props: Props, onActivated: () -> ()): TextButton
	local color: Color3 = props.BackgroundColor3 or Theme.Colors.Accent
	local defaults: Props = {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Bold,
		TextScaled = true,
		RichText = true,
		Text = "",
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local button: TextButton = Create.new("TextButton", defaults)
	Create.Corner(Theme.CornerSmall).Parent = button
	Create.Stroke(Color3.new(0, 0, 0), 2, 0.6).Parent = button
	Create.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, MinTextSize = 8, Parent = button })
	Create.new("UIPadding", {
		PaddingLeft = UDim.new(0.06, 0),
		PaddingRight = UDim.new(0.06, 0),
		PaddingTop = UDim.new(0.12, 0),
		PaddingBottom = UDim.new(0.12, 0),
		Parent = button,
	})
	local scale: UIScale = Create.new("UIScale", { Parent = button })

	local hoverInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, hoverInfo, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, hoverInfo, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, hoverInfo, { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, hoverInfo, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if button.Active then
			SoundController.Play("Click")
			onActivated()
		end
	end)
	return button
end

-- Small red "!" dot shown on nav buttons when something can be claimed.
function Create.Badge(parent: GuiObject): Frame
	local badge: Frame = Create.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.9, 0.1),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = Theme.Colors.Danger,
		Visible = false,
		ZIndex = 4,
		Parent = parent,
	}, {
		Create.Corner(UDim.new(0.5, 0)),
		Create.Stroke(Color3.new(1, 1, 1), 2),
		Create.Aspect(1),
	})
	Create.Label({ Text = "!", Size = UDim2.fromScale(1, 1), ZIndex = 5, MaxTextSize = 22, Parent = badge })
	return badge
end

function Create.SetButtonEnabled(button: TextButton, enabled: boolean, enabledColor: Color3)
	button.Active = enabled
	button.BackgroundColor3 = if enabled then enabledColor else Theme.Colors.Disabled
	button.TextTransparency = if enabled then 0 else 0.35
end

-- Standard modal panel: dark rounded frame centred on screen with a header.
function Create.Panel(name: string, title: string, accent: Color3, aspect: number, parent: Instance): (Frame, Frame, TextButton)
	local panel: Frame = Create.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.74),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, {
		Create.Corner(UDim.new(0.04, 0)),
		Create.Stroke(accent, 3),
		Create.Aspect(aspect),
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 760) }),
		Create.new("UIScale", { Name = "OpenScale" }),
	})
	if Device.IsSmallScreen() then
		-- Phones: use (almost) the whole screen so buttons stay big enough to tap.
		panel.Size = UDim2.fromScale(0.96, 0.92)
		panel.Position = UDim2.fromScale(0.5, 0.5)
	end

	local header: Frame = Create.new("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.13),
		BackgroundColor3 = accent,
		Parent = panel,
	}, { Create.Corner(UDim.new(0.3, 0)) })

	Create.Label({
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Display,
		Position = UDim2.fromScale(0.03, 0.12),
		Size = UDim2.fromScale(0.6, 0.76),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 44,
		Parent = header,
	})

	local close = Create.Button({
		Name = "Close",
		Text = "✕",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.5),
		Size = UDim2.fromScale(0.07, 0.75),
		BackgroundColor3 = Theme.Colors.Danger,
		Parent = header,
	}, function() end)
	Create.Aspect(1).Parent = close

	return panel, header, close
end

return Create
