local root, scenarioName = arg[1], arg[2]

local clock = 0
local W = {
  ped = 100, pid = 0, veh = 0, health = 200, maxHealth = 200, armor = 0, invincible = false, invincible2 = false,
  canBeDamaged = true, proofs = {}, visible = true, alpha = 255, coords = { x = 100.0, y = 200.0, z = 30.0 },
  velocity = { x = 0.0, y = 0.0, z = 0.0 }, height = 1.0, collisionOff = false, jumping = false, configFlags = {},
  ragdoll = true, spectating = false, seethrough = false, nightvision = false, sprinting = false, stamina = 100.0,
  camCoord = nil, renderingCam = -1, weapons = {}, selected = 0, weaponMods = {}, dmgMod = 1.0, meleeMod = 1.0,
  defense = 1.0, ramMod = 1.0, resources = { "jcks_anticheat", "chat", "spawnmanager", "es_extended" },
  commands = {}, textures = {}, vehicle = nil,
}
local calls = {}
local function call(name, ...) calls[#calls + 1] = name end

local function vec(t) return setmetatable({ x = t.x, y = t.y, z = t.z }, { __sub = function(a, b) return vec({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }) end }) end

local N = {}
function N.GetGameTimer() return clock end
function N.PlayerPedId() return W.ped end
function N.PlayerId() return W.pid end
function N.GetVehiclePedIsIn() return W.vehicle and 500 or 0 end
function N.IsPedInAnyVehicle() return W.vehicle ~= nil end
function N.GetPedInVehicleSeat() return W.vehicle and W.ped or 0 end
function N.NetworkGetEntityOwner() return W.vehicle and (W.vehicle.owner or W.pid) or W.pid end
function N.GetEntityHealth() return W.health end
function N.GetEntityMaxHealth() return W.maxHealth end
function N.GetPedArmour() return W.armor end
function N.GetPlayerInvincible() return W.invincible end
function N.GetPlayerInvincible_2() return W.invincible2 end
function N.GetEntityCanBeDamaged(e) if e == 500 then return W.vehicle.canBeDamaged ~= false end return W.canBeDamaged end
function N.GetEntityProofs() local p = W.proofs return true, p.bullet or 0, p.fire or 0, p.explosion or 0, 0, p.melee or 0, p.steam or 0, 0, p.drown or 0 end
function N.IsEntityVisible(e) if e == 500 then return W.vehicle.visible ~= false end return W.visible end
function N.GetEntityAlpha(e) if e == 500 then return W.vehicle.alpha or 255 end return W.alpha end
function N.GetUsingseethrough() return W.seethrough end
function N.GetUsingnightvision() return W.nightvision end
function N.GetPedConfigFlag(_, f) return W.configFlags[f] == true end
function N.NetworkIsInSpectatorMode() return W.spectating end
function N.CanPedRagdoll() return W.ragdoll end
function N.GetEntityCoords() return vec(W.coords) end
function N.GetEntityVelocity() return vec(W.velocity) end
function N.GetEntityHeightAboveGround() return W.height end
function N.GetEntityCollisionDisabled() return W.collisionOff end
function N.IsPedJumping() return W.jumping end
function N.IsPedSprinting() return W.sprinting end
function N.GetPlayerSprintStaminaRemaining() return W.stamina end
function N.GetGameplayCamCoord() return vec(W.camCoord or W.coords) end
function N.GetFinalRenderedCamCoord() return vec(W.camCoord or W.coords) end
function N.GetRenderingCam() return W.renderingCam end
function N.GetPedParachuteState() return -1 end
function N.GetIsLoadingScreenActive() return false end
function N.GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
function N.HasPedGotWeapon(_, h) return W.weapons[h] == true end
function N.GetSelectedPedWeapon() return W.selected end
function N.GetWeaponDamageModifier(h) return W.weaponMods[h] or 1.0 end
function N.GetPlayerWeaponDamageModifier() return W.dmgMod end
function N.GetPlayerMeleeWeaponDamageModifier() return W.meleeMod end
function N.GetPlayerWeaponDefenseModifier() return W.defense end
function N.GetPlayerVehicleDamageModifier() return W.ramMod end
function N.GetNumResources() return #W.resources end
function N.GetResourceByFindIndex(i) return W.resources[i + 1] end
function N.GetResourceState(r) for _, x in ipairs(W.resources) do if x == r then return "started" end end return "missing" end
function N.GetRegisteredCommands() return W.commands end
function N.HasStreamedTextureDictLoaded(d) return W.textures[d] == true end
function N.GetVehicleEngineHealth() return W.vehicle.engine end
function N.GetVehicleBodyHealth() return W.vehicle.body end
function N.GetVehicleNumberPlateText() return W.vehicle.plate end
function N.GetVehicleCustomPrimaryColour() return W.vehicle.r or 0, 0, 0 end
function N.GetVehicleColours() return W.vehicle.c1 or 0, 0 end
function N.GetEntityModel() return 1234 end
function N.GetVehicleHandlingFloat(_, _, f) return (W.vehicle.handling and W.vehicle.handling[f]) or 1.0 end
function N.GetVehicleCheatPowerIncrease() return W.vehicle.power or 1.0 end
function N.GetVehicleTopSpeedModifier() return W.vehicle.topSpeed or -1.0 end
function N.GetVehicleGravityAmount() return W.vehicle.gravity or 9.8 end
function N.GetVehicleClass() return 0 end
function N.SetPlayerInvincible(_, v) W.invincible = v call("SetPlayerInvincible") end
function N.SetPlayerInvincibleKeepRagdollEnabled(_, v) W.invincible2 = v call("SetPlayerInvincibleKeepRagdollEnabled") end
function N.SetEntityCanBeDamaged(e, v) if e == 500 then W.vehicle.canBeDamaged = v else W.canBeDamaged = v end call("SetEntityCanBeDamaged") end
function N.SetEntityProofs() W.proofs = {} call("SetEntityProofs") end
function N.SetPlayerWeaponDefenseModifier(_, v) W.defense = v call("SetPlayerWeaponDefenseModifier") end
function N.SetEntityMaxHealth(_, v) W.maxHealth = v call("SetEntityMaxHealth") end
function N.SetEntityHealth(_, v) W.health = v call("SetEntityHealth") end
function N.SetPedArmour(_, v) W.armor = v call("SetPedArmour") end
function N.SetEntityVisible(e, v) if e == 500 then W.vehicle.visible = v else W.visible = v end call("SetEntityVisible") end
function N.ResetEntityAlpha(e) if e == 500 then W.vehicle.alpha = 255 else W.alpha = 255 end call("ResetEntityAlpha") end
function N.SetSeethrough(v) W.seethrough = v call("SetSeethrough") end
function N.SetNightvision(v) W.nightvision = v call("SetNightvision") end
function N.SetPedConfigFlag(_, f, v) W.configFlags[f] = v call("SetPedConfigFlag") end
function N.NetworkSetInSpectatorMode(v) W.spectating = v call("NetworkSetInSpectatorMode") end
function N.SetPedCanRagdoll(_, v) W.ragdoll = v call("SetPedCanRagdoll") end
function N.SetEntityVelocity(_, x, y, z) W.velocity = { x = x, y = y, z = z } call("SetEntityVelocity") end
function N.SetEntityCollision(_, v) W.collisionOff = not v call("SetEntityCollision") end
function N.SetEntityCoordsNoOffset(_, x, y, z) W.coords = { x = x, y = y, z = z } call("SetEntityCoordsNoOffset") end
function N.RemoveWeaponFromPed(_, h) W.weapons[h] = nil call("RemoveWeaponFromPed") end
function N.RemoveAllPedWeapons() W.weapons = {} call("RemoveAllPedWeapons") end
function N.SetPlayerWeaponDamageModifier(_, v) W.dmgMod = v call("SetPlayerWeaponDamageModifier") end
function N.SetPlayerMeleeWeaponDamageModifier(_, v) W.meleeMod = v call("SetPlayerMeleeWeaponDamageModifier") end
function N.SetWeaponDamageModifier(h, v) W.weaponMods[h] = v call("SetWeaponDamageModifier") end
function N.SetPlayerVehicleDamageModifier(_, v) W.ramMod = v call("SetPlayerVehicleDamageModifier") end
function N.SetVehicleCheatPowerIncrease(_, v) W.vehicle.power = v call("SetVehicleCheatPowerIncrease") end
function N.ModifyVehicleTopSpeed(_, v) W.vehicle.topSpeed = v == 0.0 and -1.0 or v call("ModifyVehicleTopSpeed") end
function N.SetVehicleGravityAmount(_, v) W.vehicle.gravity = v call("SetVehicleGravityAmount") end
function N.SetVehicleEngineHealth(_, v) W.vehicle.engine = v call("SetVehicleEngineHealth") end
function N.SetVehicleBodyHealth(_, v) W.vehicle.body = v call("SetVehicleBodyHealth") end
function N.SetVehicleNumberPlateText(_, v) W.vehicle.plate = v call("SetVehicleNumberPlateText") end
function N.SetVehicleHandlingFloat(_, _, f, v) W.vehicle.handling = W.vehicle.handling or {} W.vehicle.handling[f] = v call("SetVehicleHandlingFloat") end

local threads = {}
function N.CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wake = 0 } end
function N.Wait(ms) coroutine.yield(ms or 0) end
function N.AddEventHandler() end
function N.RegisterNUICallback() end
function N.exports() end

setmetatable(_G, { __index = function(_, k)
  if N[k] then return N[k] end
  if type(k) == "string" and k:match("^[A-Z][a-z]") and not k:match("^Jcks") then
    local fn
    if k:match("^Is") or k:match("^Has") or k:match("^Does") or k:match("^Network") then fn = function() return false end
    elseif k:match("^Get") then fn = function() return 0 end
    else fn = function() call(k) end end
    N[k] = fn
    return fn
  end
end })

local function load(path) dofile(root .. "/" .. path) end
load("client/main.lua")
load("client/countermeasures.lua")
for _, f in ipairs({ "integrity", "movement", "player", "vehicle", "weapon" }) do load("client/detections/" .. f .. ".lua") end

local S
for _, v in pairs(_G) do
  if type(v) == "table" and type(rawget(v, "flag")) == "function" and type(rawget(v, "counter")) == "function" then S = v end
end
S.server.resources = { "jcks_anticheat", "chat", "spawnmanager", "es_extended" }
S.server.countermeasures = true
S.server.cmSkip = {}
S.server.textureBlacklist = { "menu_textures" }
S.server.weaponBlacklist = { [N.GetHashKey("WEAPON_RAILGUN")] = "WEAPON_RAILGUN" }
S.server.maxWeapons = 25
S.server.maxHealth = 200
S.server.damageModifier = 1.0
S.ready = true

local function drive(seconds)
  local stop = clock + seconds * 1000
  while clock < stop do
    for _, t in ipairs(threads) do
      if coroutine.status(t.co) ~= "dead" and clock >= t.wake then
        local ok, ms = coroutine.resume(t.co)
        if not ok then error(ms) end
        t.wake = clock + math.max(0, tonumber(ms) or 0)
      end
    end
    clock = clock + 50
  end
end

local veh = function(extra) local v = { engine = 1000.0, body = 1000.0, plate = "JCKS 001", owner = 0 } for k, x in pairs(extra or {}) do v[k] = x end return v end

local SCENARIOS = {
  clean = { what = "Clean player walking around", run = function() end },
  clean_vehicle = { what = "Clean player driving", run = function() W.vehicle = veh() end },
  godmode = { what = "Godmode (invincible flag)", run = function() W.invincible = true end, undone = function() return not W.invincible end },
  semi_godmode = { what = "Semi-godmode (bullet+explosion+fire proofs)", run = function() W.proofs = { bullet = 1, explosion = 1, fire = 1 } end, undone = function() return next(W.proofs) == nil end },
  max_health = { what = "Max health raised to 1000", run = function() W.maxHealth = 1000 W.health = 1000 end, undone = function() return W.maxHealth == 200 end },
  invisible = { what = "Invisible on foot", run = function() W.visible = false end, undone = function() return W.visible end },
  invisible_vehicle = { what = "Invisible vehicle", run = function() W.vehicle = veh({ visible = false }) end, undone = function() return W.vehicle.visible end },
  thermal = { what = "Thermal vision", run = function() W.seethrough = true end, undone = function() return not W.seethrough end },
  tiny_ped = { what = "Tiny ped (config flag 223)", run = function() W.configFlags[223] = true end, undone = function() return not W.configFlags[223] end },
  spectate = { what = "Spectating another player", run = function() W.spectating = true end, undone = function() return not W.spectating end },
  no_ragdoll = { what = "No ragdoll", run = function() W.ragdoll = false end, undone = function() return W.ragdoll end },
  speedhack = { what = "Speedhack on foot (25 m/s)", run = function() W.velocity = { x = 25.0, y = 0.0, z = 0.0 } end },
  superjump = { what = "Super jump (14 m/s up)", run = function() W.jumping = true W.velocity = { x = 0.0, y = 0.0, z = 14.0 } end },
  freecam = { what = "Freecam 80 m away", run = function() W.camCoord = { x = 180.0, y = 200.0, z = 30.0 } end },
  noclip = { what = "Noclip (collision off)", run = function() W.collisionOff = true end, undone = function() return not W.collisionOff end },
  noclip_float = { what = "Noclip hovering 20 m up", run = function() W.height = 20.0 end },
  blacklisted_weapon = { what = "Blacklisted weapon (railgun)", run = function() local h = N.GetHashKey("WEAPON_RAILGUN") W.weapons[h] = true end, undone = function() return W.weapons[N.GetHashKey("WEAPON_RAILGUN")] == nil end },
  give_all_weapons = { what = "Give all weapons", run = function() for _, n in ipairs({ "WEAPON_PISTOL", "WEAPON_SMG", "WEAPON_MG", "WEAPON_RPG", "WEAPON_KNIFE", "WEAPON_BAT", "WEAPON_MINIGUN", "WEAPON_GRENADE", "WEAPON_MOLOTOV", "WEAPON_SNIPERRIFLE", "WEAPON_HEAVYSNIPER", "WEAPON_ASSAULTRIFLE", "WEAPON_CARBINERIFLE", "WEAPON_PUMPSHOTGUN", "WEAPON_COMBATMG", "WEAPON_GUSENBERG", "WEAPON_MUSKET", "WEAPON_HAMMER", "WEAPON_CROWBAR", "WEAPON_MACHETE", "WEAPON_FLAREGUN", "WEAPON_REVOLVER", "WEAPON_MICROSMG", "WEAPON_APPISTOL", "WEAPON_STUNGUN", "WEAPON_PISTOL50", "WEAPON_STICKYBOMB", "WEAPON_FIREWORK" }) do W.weapons[N.GetHashKey(n)] = true end end, undone = function() return next(W.weapons) == nil end },
  damage_multiplier = { what = "Weapon damage x5", run = function() W.dmgMod = 5.0 end, undone = function() return W.dmgMod == 1.0 end },
  weapon_modifier = { what = "Pistol damage modifier x10", run = function() W.selected = 77 W.weaponMods[77] = 10.0 end, undone = function() return W.weaponMods[77] == 1.0 end },
  vehicle_repair = { what = "Instant vehicle repair", run = function() W.vehicle = veh({ engine = 300.0, body = 300.0 }) drive(1) W.vehicle.engine = 1000.0 W.vehicle.body = 1000.0 end, undone = function() return W.vehicle.engine < 600 end },
  mechanic_repair = { what = "Repair by a mechanic on another client (must NOT flag)", run = function() W.vehicle = veh({ engine = 300.0, body = 300.0 }) drive(1) W.vehicle.owner = 9 W.vehicle.engine = 1000.0 W.vehicle.body = 1000.0 end },
  plate_change = { what = "Plate changed while driving", run = function() W.vehicle = veh() drive(1) W.vehicle.plate = "CHEATER" end, undone = function() return W.vehicle.plate == "JCKS 001" end },
  power_boost = { what = "Engine power x3", run = function() W.vehicle = veh({ power = 3.0 }) end, undone = function() return W.vehicle.power == 1.0 end },
  top_speed = { what = "Top speed +500%", run = function() W.vehicle = veh({ topSpeed = 500.0 }) end, undone = function() return W.vehicle.topSpeed == -1.0 end },
  gravity = { what = "Vehicle gravity 0 (fly/wall ride)", run = function() W.vehicle = veh({ gravity = 0.0 }) end, undone = function() return W.vehicle.gravity == 9.8 end },
  ram_damage = { what = "Vehicle ramming damage x10", run = function() W.vehicle = veh() W.ramMod = 10.0 end, undone = function() return W.ramMod == 1.0 end },
  vehicle_godmode = { what = "Vehicle godmode", run = function() W.vehicle = veh({ canBeDamaged = false }) end, undone = function() return W.vehicle.canBeDamaged end },
  injected_resource = { what = "Injected fake resource", run = function() W.resources[#W.resources + 1] = "totally_legit_menu" end },
  injected_command = { what = "Command registered by an unknown resource", run = function() W.commands = { { name = "openmenu", resource = "redmenu" } } end },
  menu_texture = { what = "Menu texture dictionary loaded", run = function() W.textures["menu_textures"] = true end },
}

local EXPECT = {
  clean = "none", clean_vehicle = "none", mechanic_repair = "none", godmode = "PLY_GODMODE_FLAG", semi_godmode = "PLY_GODMODE_PROOFS",
  max_health = "PLY_HEALTH_CAP", invisible = "PLY_INVISIBLE", invisible_vehicle = "PLY_INVISIBLE", thermal = "PLY_VISION",
  tiny_ped = "PLY_TINY_PED", spectate = "PLY_SPECTATE", no_ragdoll = "PLY_NO_RAGDOLL", speedhack = "PLY_SPEED_FOOT",
  superjump = "PLY_SUPERJUMP", freecam = "MOV_FREECAM", noclip = "MOV_NOCLIP_COLLISION", noclip_float = "MOV_NOCLIP_FLOAT",
  blacklisted_weapon = "WPN_BLACKLIST", give_all_weapons = "WPN_GIVE_ALL", damage_multiplier = "WPN_DMG_MODIFIER",
  weapon_modifier = "WPN_DMG_MODIFIER", vehicle_repair = "VEH_REPAIR", plate_change = "VEH_PLATE", power_boost = "VEH_POWER",
  top_speed = "VEH_TOP_SPEED", gravity = "VEH_GRAVITY", ram_damage = "VEH_DMG_MODIFIER", vehicle_godmode = "VEH_GODMODE",
  injected_resource = "EXE_RESOURCE_INJECT", injected_command = "EXE_COMMAND_INJECT", menu_texture = "EXE_MENU_TEXTURE",
}

if scenarioName == "all" then
  local names = {}
  for k in pairs(SCENARIOS) do names[#names + 1] = k end
  table.sort(names)
  local lua, failed = arg[-1] or "lua5.4", 0
  for _, name in ipairs(names) do
    local h = io.popen(lua .. " " .. arg[0] .. " " .. root .. " " .. name)
    local line = h:read("l") or ""
    h:close()
    local _, what, codes, undone = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
    local want = EXPECT[name]
    local ok = codes == want and undone ~= "NO"
    if not ok then failed = failed + 1 end
    print(string.format("%-4s %-20s %-58s %-26s undone=%s", ok and "PASS" or "FAIL", name, what or "?", codes or "?", undone or "?"))
  end
  print(failed == 0 and ("CLIENT SIM OK (" .. #names .. " scenarios)") or (failed .. " scenario(s) failed"))
  os.exit(failed == 0 and 0 or 1)
end

local sc = SCENARIOS[scenarioName]
if not sc then
  local names = {}
  for k in pairs(SCENARIOS) do names[#names + 1] = k end
  table.sort(names)
  print(table.concat(names, " "))
  return
end

drive(20)
for _, f in ipairs(S.drainFlags()) do if os.getenv("SIM_DEBUG") then print("warmup", f.c, f.d and (f.d.e or f.d.n) or "") end end
calls = {}
sc.run()
drive(12)
local codes, seen = {}, {}
for _, f in ipairs(S.drainFlags()) do
  if not seen[f.c] then seen[f.c] = true codes[#codes + 1] = f.c end
end
local undone = sc.undone and (sc.undone() and "yes" or "NO") or "-"
local cm = {}
local cs = {}
for _, c in ipairs(calls) do if not cs[c] then cs[c] = true cm[#cm + 1] = c end end
print(scenarioName .. "\t" .. sc.what .. "\t" .. (#codes > 0 and table.concat(codes, ",") or "none") .. "\t" .. undone .. "\t" .. table.concat(cm, ","))
