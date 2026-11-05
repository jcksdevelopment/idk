--!strict
-- Visual tokens for the programmatic UI: bright, high-contrast, kid-friendly.

local Theme = {}

Theme.Colors = {
	Backdrop = Color3.fromRGB(14, 16, 30),
	Panel = Color3.fromRGB(36, 40, 70),
	PanelLight = Color3.fromRGB(54, 60, 100),
	PanelDark = Color3.fromRGB(24, 27, 48),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 196, 230),
	Accent = Color3.fromRGB(255, 196, 40),
	Success = Color3.fromRGB(60, 210, 110),
	Danger = Color3.fromRGB(255, 85, 85),
	Info = Color3.fromRGB(70, 160, 255),
	Robux = Color3.fromRGB(0, 185, 95),
	VIP = Color3.fromRGB(175, 100, 255),
	Pink = Color3.fromRGB(255, 110, 180),
	XP = Color3.fromRGB(120, 230, 255),
	Disabled = Color3.fromRGB(90, 94, 120),
}

Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Bold = Enum.Font.GothamBold,
	Regular = Enum.Font.GothamMedium,
}

Theme.CornerScale = UDim.new(0.12, 0)
Theme.CornerSmall = UDim.new(0.3, 0)

Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
})

return table.freeze(Theme)
