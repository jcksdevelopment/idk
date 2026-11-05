local root = arg[1]
local log = {}
local function rec(name) return function(...) log[#log + 1] = name .. ":" .. table.concat((function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end return t end)(...), ",") end end
function GetGameTimer() return 1000 end
function CreateThread() end
function Wait() end
function exports() end
function IsPlayerSwitchInProgress() return false end
function IsScreenFadedOut() return false end
function IsScreenFadingIn() return false end
function GetIsLoadingScreenActive() return false end
function IsPedDeadOrDying() return false end
function PlayerPedId() return 42 end
function PlayerId() return 0 end
function GetVehiclePedIsIn() return 0 end
SetPlayerInvincible = rec("SetPlayerInvincible")
SetEntityInvincible = rec("SetEntityInvincible")
SetEntityCanBeDamaged = rec("SetEntityCanBeDamaged")
SetEntityHealth = rec("SetEntityHealth")
RemoveAllPedWeapons = rec("RemoveAllPedWeapons")

dofile(root .. "/client/main.lua")
dofile(root .. "/client/countermeasures.lua")
local S
for _, v in pairs(_G) do
  if type(v) == "table" and type(rawget(v, "flag")) == "function" and type(rawget(v, "counter")) == "function" then S = v end
end
assert(S, "scanner table not found")
local function expect(c, m) if not c then print("FAIL: " .. m .. " | " .. table.concat(log, " ")) os.exit(1) end end
local function reset() log = {} S.lastFlagAt = {} end

S.server.countermeasures = true
S.server.cmSkip = {}
S.flag("PLY_GODMODE_FLAG", {})
expect(log[1] == "SetPlayerInvincible:0,false", "godmode not switched off")

reset()
S.flag("WPN_GIVE_ALL", { n = 40 })
expect(log[1] == "RemoveAllPedWeapons:42,true", "weapons not removed")

reset()
S.flag("PLY_HEALTH_REGEN", { from = 120, to = 200 })
expect(#log == 0, "health reverted without the shield")
S.shielded = { qb_core = true }
reset()
S.flag("PLY_HEALTH_REGEN", { from = 120, to = 200 })
expect(log[1] == "SetEntityHealth:42,120", "health not reverted with the shield")
reset()
S.flag("PLY_SELF_REVIVE", {})
expect(log[1] == "SetEntityHealth:42,0", "self revive not undone")

reset()
S.server.cmSkip = { PLY_GODMODE_FLAG = true }
S.flag("PLY_GODMODE_FLAG", {})
expect(#log == 0, "skip list ignored")

reset()
S.server.cmSkip = {}
S.server.bypass = true
S.flag("PLY_GODMODE_FLAG", {})
expect(#log == 0, "admin bypass ignored")

reset()
S.server.bypass = false
S.server.countermeasures = false
S.flag("PLY_GODMODE_FLAG", {})
expect(#log == 0, "countermeasures off but applied")

reset()
S.server.countermeasures = true
S.flag("PLY_GODMODE_FLAG", {})
S.flag("PLY_GODMODE_FLAG", {})
expect(#log == 6, "countermeasure must apply on every detection, not only outside the flag cooldown (" .. #log .. ")")
expect(S.t("footSpeed") == 12, "default threshold")
S.server.thresholds = { footSpeed = 20 }
expect(S.t("footSpeed") == 20 and S.t("healthJump") == 25, "server threshold override")
print("COUNTERMEASURES OK")
