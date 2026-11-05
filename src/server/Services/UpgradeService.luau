--!strict
--[[
	UpgradeService
	Workshop upgrades bought with in-game cash. Price and max level come from
	Config.Upgrades; the client only sends the upgrade key. Cash check,
	payment and level-up happen in one non-yielding block.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Upgrades = require(Shared.Upgrades)

local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local SyncService = require(script.Parent.SyncService)

local UpgradeService = {}

local function onBuyUpgrade(player: Player, key: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local data = profile.Data
	local level = data.Upgrades[key] or 0
	local cost = Upgrades.Cost(key, level)
	if not cost then
		SyncService.Notify(player, "info", "N_UpgradeMax")
		return
	end
	if data.Cash < cost then
		SyncService.Notify(player, "error", "N_NotEnoughCash")
		return
	end
	-- Atomic: pay, level up.
	data.Cash -= cost
	data.Upgrades[key] = level + 1
	SyncService.Notify(player, "success", "N_UpgradeBought", { "@upg:" .. key, tostring(level + 1) })
	ProgressService.CheckAchievements(player, data)
	SyncService.MarkDirty(player)
end

function UpgradeService.Start()
	RemoteGuard.Bind("BuyUpgrade", {
		RatePerSecond = 4,
		Burst = 8,
		Args = { RemoteGuard.Validators.OneOf(Config.Upgrades.Order) },
	}, onBuyUpgrade)
end

return UpgradeService
