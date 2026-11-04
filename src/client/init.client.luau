--!strict
--[[
	Client bootstrap.
	The client is a VIEW: it renders server snapshots and sends requests.
	Nothing here can grant cash, items or time; the server decides everything.
]]

local Controllers = script:WaitForChild("Controllers")
local UI = script:WaitForChild("UI")

local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)
local InputController = require(Controllers.InputController)
local RepairController = require(Controllers.RepairController)

local Toast = require(UI.Toast)
local HUD = require(UI.HUD)
local InventoryPanel = require(UI.InventoryPanel)
local BazaarPanel = require(UI.BazaarPanel)
local CashShopPanel = require(UI.CashShopPanel)

local gui = UIController.CreateGui()

Toast.Build(gui)
HUD.Build(gui)
InventoryPanel.Build(gui)
BazaarPanel.Build(gui)
CashShopPanel.Build(gui)

UIController.Start()
InputController.Start()
RepairController.Start()
StateController.Start() -- last: snapshots arrive once every view is listening
