--!strict
--[[
	Device
	Small helpers to adapt the UI to phones/tablets (touch, no keyboard) and
	small screens. Purely cosmetic.
]]

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Device = {}

-- Touch device without a keyboard (phone / tablet).
function Device.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Short screens (most phones in landscape are < 500 px tall).
function Device.IsSmallScreen(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	return camera.ViewportSize.Y < 560
end

-- Keyboard hint like " [I]" — hidden on touch devices where it means nothing.
function Device.KeyHint(key: string): string
	if key == "" or Device.IsTouch() then
		return ""
	end
	return " [" .. key .. "]"
end

return Device
