--!strict
--[[
	OverheadController
	Shows a name tag above every player: their equipped trophy title, level
	and New Start stars. The server publishes Level / Rebirths / Title as
	Player attributes; each client renders and localizes them locally.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local OverheadController = {}

type Tag = { Gui: BillboardGui, Title: TextLabel, Info: TextLabel }

local tags: { [Player]: Tag } = {}

local function render(player: Player)
	local tag = tags[player]
	if not tag then
		return
	end
	local title = player:GetAttribute("Title")
	local level = player:GetAttribute("Level")
	local rebirths = player:GetAttribute("Rebirths")
	tag.Title.Text = if type(title) == "string" and title ~= "" then "🏅 " .. Locale.T("Ach_" .. title) else ""
	local info = if type(level) == "number" then "⭐ " .. Locale.T("HUD_Level", { tostring(level) }) else ""
	if type(rebirths) == "number" and rebirths > 0 then
		info ..= "   🔄×" .. tostring(rebirths)
	end
	if player:GetAttribute("GoldenName") == true then
		-- Golden Name pass: sparkly golden name line
		info = "✨ " .. player.DisplayName .. " ✨   " .. info
		tag.Info.TextColor3 = Color3.fromRGB(255, 215, 80)
	else
		tag.Info.TextColor3 = Color3.new(1, 1, 1)
	end
	tag.Info.Text = info
end

local function attach(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = tags[player]
	if old then
		old.Gui:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "BazarTag"
	gui.ResetOnSpawn = false -- lives in PlayerGui: must survive the local player's respawn
	gui.Adornee = head
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 210, 70)
	title.TextStrokeTransparency = 0.2
	title.Parent = gui

	local info = Instance.new("TextLabel")
	info.Position = UDim2.fromScale(0, 0.55)
	info.Size = UDim2.fromScale(1, 0.45)
	info.BackgroundTransparency = 1
	info.TextScaled = true
	info.Font = Enum.Font.GothamBold
	info.TextColor3 = Color3.new(1, 1, 1)
	info.TextStrokeTransparency = 0.3
	info.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	tags[player] = { Gui = gui, Title = title, Info = info }
	render(player)
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
	for _, attribute in { "Title", "Level", "Rebirths", "GoldenName" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			render(player)
		end)
	end
end

-- Re-localize every tag (called after a language change).
function OverheadController.Refresh()
	for player in tags do
		render(player)
	end
end

function OverheadController.Start()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local tag = tags[player]
		if tag then
			tag.Gui:Destroy()
			tags[player] = nil
		end
	end)
end

return OverheadController
