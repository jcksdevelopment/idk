--!strict
--[[
	Effects
	Juicy, purely cosmetic UI feedback: floating "+$120" popups, confetti
	showers and soap bubbles for the scrub mini-game.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Effects = {}

local layer: Frame? = nil

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(220, 110, 255),
}

function Effects.Build(gui: ScreenGui)
	layer = Create.new("Frame", {
		Name = "Effects",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	})
end

-- Floating text that rises and fades. `position` is in scale (0..1).
function Effects.Popup(text: string, color: Color3, position: UDim2)
	local parent = layer
	if not parent then
		return
	end
	local label = Create.Label({
		Text = text,
		Font = Theme.Fonts.Display,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromScale(0.2, 0.06),
		ZIndex = 51,
		MaxTextSize = 40,
		Parent = parent,
	})
	local scale = Create.new("UIScale", { Scale = 0.4, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = position - UDim2.fromScale(0, 0.08),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.15, function()
		label:Destroy()
	end)
end

function Effects.Confetti(count: number)
	local parent = layer
	if not parent then
		return
	end
	for _ = 1, count do
		local startX = math.random()
		local piece: Frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(startX, -0.05),
			Size = UDim2.fromScale(0.012, 0.022),
			BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)],
			Rotation = math.random(0, 360),
			ZIndex = 52,
			Parent = parent,
		})
		local duration = 1.6 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(startX + (math.random() - 0.5) * 0.3, 1.05),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

-- Soap bubbles at the pointer (mouse or last touch).
function Effects.Bubbles(count: number)
	local parent = layer
	if not parent then
		return
	end
	-- GetMouseLocation includes the top bar inset; convert to the layer's space.
	local inset = GuiService:GetGuiInset()
	local mouse = UserInputService:GetMouseLocation() - inset - parent.AbsolutePosition
	local size = parent.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local origin = Vector2.new(math.clamp(mouse.X / size.X, 0, 1), math.clamp(mouse.Y / size.Y, 0, 1))
	for _ = 1, count do
		local bubble: Frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(origin.X, origin.Y),
			Size = UDim2.fromScale(0.02, 0.02),
			BackgroundColor3 = Color3.fromRGB(200, 235, 255),
			BackgroundTransparency = 0.35,
			ZIndex = 52,
			Parent = parent,
		}, {
			Create.Corner(UDim.new(0.5, 0)),
			Create.Stroke(Color3.new(1, 1, 1), 1.5, 0.2),
			Create.Aspect(1),
		})
		local drift = UDim2.fromScale((math.random() - 0.5) * 0.08, -0.05 - math.random() * 0.06)
		TweenService:Create(bubble, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = bubble.Position + drift,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.035, 0.035),
		}):Play()
		task.delay(0.7, function()
			bubble:Destroy()
		end)
	end
end

return Effects
