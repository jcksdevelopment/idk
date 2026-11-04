--!strict
-- Visual tokens for the programmatic UI.

local Theme = {}

Theme.Colors = {
	Backdrop = Color3.fromRGB(10, 12, 20),
	Panel = Color3.fromRGB(30, 33, 48),
	PanelLight = Color3.fromRGB(44, 48, 68),
	PanelDark = Color3.fromRGB(22, 24, 36),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(168, 174, 196),
	Accent = Color3.fromRGB(255, 186, 26),
	Success = Color3.fromRGB(46, 204, 113),
	Danger = Color3.fromRGB(231, 76, 60),
	Info = Color3.fromRGB(52, 152, 219),
	Robux = Color3.fromRGB(0, 178, 89),
	VIP = Color3.fromRGB(155, 89, 182),
	Disabled = Color3.fromRGB(80, 84, 100),
}

Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Bold = Enum.Font.GothamBold,
	Regular = Enum.Font.Gotham,
}

Theme.CornerScale = UDim.new(0.12, 0)
Theme.CornerSmall = UDim.new(0.25, 0)

return table.freeze(Theme)
