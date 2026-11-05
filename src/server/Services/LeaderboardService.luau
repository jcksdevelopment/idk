--!strict
--[[
	LeaderboardService
	Global "Top earners" board on the plaza, backed by an OrderedDataStore
	keyed by UserId with LifetimeEarned (server-owned) as the value.
	Silently disabled when DataStores are unavailable (e.g. Studio without
	API access), so it never breaks the game.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local names: { [number]: string } = {}
local rows: { TextLabel } = {}

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and type(name) == "string" then name else "Player"
	names[userId] = result
	return result
end

local function buildBoard(): Part
	local position = Config.Leaderboard.Position
	local board = Instance.new("Part")
	board.Name = "Leaderboard"
	board.Anchored = true
	board.Size = Vector3.new(14, 16, 1)
	board.CFrame = CFrame.lookAt(position + Vector3.new(0, 8.5, 0), Vector3.new(0, 8.5, -10))
	board.Color = Color3.fromRGB(40, 44, 80)
	board.Material = Enum.Material.SmoothPlastic

	local frameTop = Instance.new("Part")
	frameTop.Name = "Trim"
	frameTop.Anchored = true
	frameTop.Size = Vector3.new(15, 1, 1.4)
	frameTop.CFrame = board.CFrame * CFrame.new(0, 8.5, 0)
	frameTop.Color = Color3.fromRGB(255, 196, 40)
	frameTop.Material = Enum.Material.Neon
	frameTop.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 640)
	gui.LightInfluence = 0
	gui.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 80)
	title.BackgroundTransparency = 1
	title.Text = "🏆 TOP 10 💰"
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 196, 40)
	title.Parent = gui

	for index = 1, Config.Leaderboard.Size do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = index
		row.Size = UDim2.new(0.94, 0, 0, 48)
		row.BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(54, 60, 100) else Color3.fromRGB(46, 50, 88)
		row.Text = ""
		row.TextScaled = true
		row.Font = Enum.Font.GothamBold
		row.TextColor3 = if index == 1
			then Color3.fromRGB(255, 215, 80)
			elseif index == 2 then Color3.fromRGB(220, 225, 235)
			elseif index == 3 then Color3.fromRGB(230, 160, 100)
			else Color3.new(1, 1, 1)
		row.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row
		table.insert(rows, row)
	end

	board.Parent = Workspace:FindFirstChild("Bazaar") or Workspace
	return board
end

local function refresh(store: OrderedDataStore)
	-- 1. Publish online players' scores.
	for _, player in Players:GetPlayers() do
		local profile = DataService.GetProfile(player)
		if profile then
			local score = math.floor(math.min(profile.Data.LifetimeEarned, 2 ^ 52))
			pcall(store.SetAsync, store, tostring(player.UserId), score)
		end
	end

	-- 2. Read the top N.
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Leaderboard.Size)
	if not ok or not pages then
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage()
	local medals = { "🥇", "🥈", "🥉" }
	for index, row in rows do
		local entry = entries[index]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = string.format("%s  %s  ·  %s", medals[index] or ("#" .. index), nameFor(userId), Format.Cash(entry.value))
		else
			row.Text = ""
		end
	end
end

function LeaderboardService.Start()
	task.spawn(function()
		-- Wait for DataService to pick a store so we know if we are on the mock.
		task.wait(5)
		buildBoard()
		if DataService.IsUsingMock() then
			rows[1].Text = "(DataStores off in Studio)"
			return
		end
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.Leaderboard.StoreName)
		if not ok then
			return
		end
		while true do
			local success, err = pcall(refresh, store :: OrderedDataStore)
			if not success then
				warn("[Leaderboard] refresh failed:", err)
			end
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
