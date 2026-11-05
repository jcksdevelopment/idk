-- JCKS Anticheat shield. Installed into every resource's fxmanifest as the first client script
-- (`/jac shield install`), so it runs inside each resource's own Lua state: the place a Lua executor
-- injects menu code into.
--
-- Every chunk FiveM loads from a resource file is named "@@<resource>/<path>". Code an executor
-- pushes into the state has no such file behind it. The shield wraps the functions menus need
-- (server events, spawning, weapons, teleport, godmode, explosions...) and walks the caller's
-- stack on each call; a frame from a chunk that isn't a resource file means injected code is
-- driving it. It also watches for new global functions defined by such chunks and for its own
-- wrappers being swapped back out.
--
-- Plain Lua 5.3/5.4 compatible, no globals of its own. Reports go to the scanner as a local event.

local RES = GetCurrentResourceName()
local REPORT = "jcks_anticheat:shield"
local getinfo = debug and debug.getinfo
if not getinfo then return end

local sourceCache = {}

-- Is this chunk name a real script (a resource file or a citizen runtime script)?
local function legitSource(src)
  local cached = sourceCache[src]
  if cached ~= nil then return cached end
  local ok = false
  if src == "=[C]" or src:find("^@?@?citizen:") then
    ok = true
  else
    local res = src:match("^@@?([%w%._%-]+)/.+")
    if res then
      local state = GetResourceState(res)
      ok = state == "started" or state == "starting"
    end
  end
  sourceCache[src] = ok
  return ok
end

local reported = {}
local function report(kind, detail)
  local key = kind .. ":" .. tostring(detail.fn) .. ":" .. tostring(detail.src)
  if reported[key] then return end
  reported[key] = true
  TriggerEvent(REPORT, RES, kind, detail)
end

-- Walk the stack above the wrapper; any frame from a non-file chunk means injected code.
local function injectedCaller()
  for level = 3, 24 do
    local info = getinfo(level, "S")
    if not info then return nil end
    local src = info.source or "?"
    if info.what ~= "C" and not legitSource(src) then
      return src:sub(1, 80)
    end
  end
  return nil
end

-- What a legitimate call means for the anticheat. When a trusted resource (integrations in the
-- settings) heals, teleports, etc. the local player, the scanner grants grace for that behaviour.
local KIND = {
  SetEntityHealth = "heal", NetworkResurrectLocalPlayer = "heal", SetPedArmour = "armor",
  SetEntityInvincible = "godmode", SetPlayerInvincible = "godmode", SetEntityProofs = "godmode", SetEntityCanBeDamaged = "godmode",
  SetEntityCoords = "teleport", SetEntityCoordsNoOffset = "teleport", SetPedCoordsKeepVehicle = "teleport", StartPlayerTeleport = "teleport",
  SetEntityVisible = "invisible", SetEntityCollision = "noclip", NetworkSetInSpectatorMode = "spectate",
  SetVehicleFixed = "vehicle", SetVehicleEngineHealth = "vehicle", SetVehicleCheatPowerIncrease = "vehicle", SetVehicleHandlingFloat = "vehicle",
  SetVehicleNumberPlateText = "vehicle", SetVehicleColours = "vehicle", SetVehicleCustomPrimaryColour = "vehicle",
  GiveWeaponToPed = "weapons", SetPedAmmo = "weapons", SetPedInfiniteAmmoClip = "weapons",
  RenderScriptCams = "camera", SetCamActive = "camera", SetPedCanRagdoll = "ragdoll",
}
local SELF_ARG = { SetPlayerInvincible = true, NetworkSetInSpectatorMode = false, RenderScriptCams = false, SetCamActive = false, NetworkResurrectLocalPlayer = false }

local lastUse = {}
local function aboutMe(name, first)
  if SELF_ARG[name] == false then return true end
  if SELF_ARG[name] then return first == PlayerId() end
  local ped = PlayerPedId()
  if first == ped then return true end
  local veh = GetVehiclePedIsIn(ped, false)
  return veh ~= 0 and first == veh
end

local function reportUse(name, first)
  local kind = KIND[name]
  if not kind or not aboutMe(name, first) then return end
  local now = GetGameTimer()
  if lastUse[kind] and now - lastUse[kind] < 1500 then return end
  lastUse[kind] = now
  TriggerEvent(REPORT, RES, "use", { fn = name, src = kind })
end

local wrappers = {}
local function guard(name)
  local original = _G[name]
  if type(original) ~= "function" then return end
  local wrapper = function(...)
    local src = injectedCaller()
    if src then
      report("call", { fn = name, src = src })
    elseif KIND[name] then
      reportUse(name, (...))
    end
    return original(...)
  end
  wrappers[name] = wrapper
  _G[name] = wrapper
end

-- What Lua menus call. Natives are resolved lazily in FiveM; reading _G[name] resolves them.
local GUARDED = {
  "TriggerServerEvent", "TriggerLatentServerEvent", "ExecuteCommand", "RegisterCommand",
  "CreateVehicle", "CreatePed", "CreateObject", "CreateObjectNoOffset",
  "GiveWeaponToPed", "SetPedAmmo", "SetPedInfiniteAmmoClip", "SetPlayerWeaponDamageModifier",
  "SetEntityCoords", "SetEntityCoordsNoOffset", "SetPedCoordsKeepVehicle", "StartPlayerTeleport",
  "SetEntityInvincible", "SetPlayerInvincible", "SetEntityProofs", "SetEntityCanBeDamaged",
  "SetEntityHealth", "SetPedArmour", "SetEntityVisible", "SetEntityCollision",
  "AddExplosion", "AddOwnedExplosion", "ShootSingleBulletBetweenCoords", "StartScriptFire",
  "SetVehicleFixed", "SetVehicleEngineHealth", "SetVehicleCheatPowerIncrease", "SetVehicleHandlingFloat",
  "NetworkResurrectLocalPlayer", "SetRunSprintMultiplierForPlayer", "SetSuperJumpThisFrame",
  "ClearPedTasksImmediately", "AttachEntityToEntity", "NetworkSetInSpectatorMode",
  "SetVehicleNumberPlateText", "SetVehicleColours", "SetVehicleCustomPrimaryColour",
  "RenderScriptCams", "SetCamActive", "SetPedCanRagdoll",
}
for i = 1, #GUARDED do guard(GUARDED[i]) end
if Citizen and type(Citizen.InvokeNative) == "function" then
  local invoke = Citizen.InvokeNative
  local wrapped = function(...)
    local src = injectedCaller()
    if src then report("call", { fn = "Citizen.InvokeNative", src = src }) end
    return invoke(...)
  end
  Citizen.InvokeNative = wrapped
  wrappers["Citizen.InvokeNative"] = wrapped
end

-- Watch globals: new functions from non-file chunks, and wrappers being replaced.
local known = {}
local function scanGlobals()
  for name, value in pairs(_G) do
    if not known[name] then
      known[name] = true
      if type(value) == "function" then
        local info = getinfo(value, "S")
        if info and info.what ~= "C" and not legitSource(info.source or "?") then
          report("global", { fn = tostring(name):sub(1, 48), src = (info.source or "?"):sub(1, 80) })
        end
      end
    end
  end
  for name, wrapper in pairs(wrappers) do
    local current = name == "Citizen.InvokeNative" and Citizen.InvokeNative or rawget(_G, name)
    if current ~= wrapper then report("tamper", { fn = name, src = "replaced" }) end
  end
end

CreateThread(function()
  -- Let the resource's own scripts define their globals first.
  Wait(15000)
  for name in pairs(_G) do known[name] = true end
  TriggerEvent(REPORT, RES, "hello", { fn = "", src = "" })
  while true do
    Wait(10000)
    scanGlobals()
  end
end)

if GetResourceMetadata(RES, "jac_antidump", 0) == "yes" then
  RegisterNetEvent("jcks_anticheat:ad:" .. RES, function(payload)
    local files = json.decode(payload)
    if type(files) ~= "table" then return end
    for _, f in ipairs(files) do
      local fn, err = load(f.c, "@@" .. RES .. "/" .. f.n)
      if fn then
        local ok, e = pcall(fn)
        if not ok then print(("[jcks_anticheat] %s/%s: %s"):format(RES, f.n, tostring(e))) end
      else
        print(("[jcks_anticheat] %s/%s: %s"):format(RES, f.n, tostring(err)))
      end
    end
  end)
  CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    TriggerServerEvent("jcks_anticheat:ad", RES)
  end)
end
