--!strict
--[[
	InputController
	Keyboard / gamepad shortcuts for the panels. Touch players use the HUD
	buttons. Inputs consumed by Roblox (chat, textboxes) are ignored.
]]

local UserInputService = game:GetService("UserInputService")

local UIController = require(script.Parent.UIController)

local InputController = {}

local BINDINGS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.B] = "Bazaar",
	[Enum.KeyCode.Q] = "Rewards",
	[Enum.KeyCode.C] = "Index",
	[Enum.KeyCode.P] = "CashShop",
	[Enum.KeyCode.T] = "Trophies",
	[Enum.KeyCode.L] = "Wheel",
	[Enum.KeyCode.ButtonY] = "Inventory",
	[Enum.KeyCode.ButtonX] = "Bazaar",
	[Enum.KeyCode.ButtonL1] = "Rewards",
	[Enum.KeyCode.ButtonR1] = "Index",
}

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local panel = BINDINGS[input.KeyCode]
		if panel then
			UIController.Toggle(panel)
		elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
			UIController.Close()
		end
	end)
end

return InputController
