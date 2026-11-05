local S = JcksAC

local function enabled(code)
  return S.server.countermeasures and not S.server.bypass and not (S.server.cmSkip and S.server.cmSkip[code])
    and not (S.server.bypassCodes and S.server.bypassCodes[code])
end

function S.shieldActive()
  return S.shielded ~= nil and next(S.shielded) ~= nil
end

local function myVehicle()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and veh or nil
end

local function backToGround()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  local subject = veh ~= 0 and veh or ped
  SetEntityCollision(subject, true, true)
  FreezeEntityPosition(subject, false)
  local g = S.lastGround
  if g then
    SetEntityCoordsNoOffset(subject, g.x, g.y, g.z, false, false, false)
  else
    SetEntityVelocity(subject, 0.0, 0.0, -10.0)
  end
end

local NEEDS_SHIELD = { PLY_HEALTH_REGEN = true, PLY_ARMOR_REGEN = true, PLY_SELF_REVIVE = true }

local ACT = {
  PLY_GODMODE_FLAG = function()
    local ped, pid = PlayerPedId(), PlayerId()
    SetPlayerInvincible(pid, false)
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)
  end,
  PLY_GODMODE_PROOFS = function()
    local ped, pid = PlayerPedId(), PlayerId()
    SetEntityProofs(ped, false, false, false, false, false, false, false, false)
    SetPlayerWeaponDefenseModifier(pid, 1.0)
    SetPlayerMeleeWeaponDefenseModifier(pid, 1.0)
  end,
  PLY_HEALTH_CAP = function()
    local ped, max = PlayerPedId(), S.server.maxHealth or 200
    SetEntityMaxHealth(ped, max)
    if GetEntityHealth(ped) > max then SetEntityHealth(ped, max) end
  end,
  PLY_HEALTH_REGEN = function(d) if d.from then SetEntityHealth(PlayerPedId(), d.from) end end,
  PLY_ARMOR_REGEN = function(d) if d.from then SetPedArmour(PlayerPedId(), d.from) end end,
  PLY_SELF_REVIVE = function() SetEntityHealth(PlayerPedId(), 0) end,
  PLY_INVISIBLE = function()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
  end,
  PLY_VISION = function()
    SetSeethrough(false)
    SetNightvision(false)
  end,
  PLY_TINY_PED = function() SetPedConfigFlag(PlayerPedId(), 223, false) end,
  PLY_SPECTATE = function() NetworkSetInSpectatorMode(false, PlayerPedId()) end,
  PLY_NO_RAGDOLL = function() SetPedCanRagdoll(PlayerPedId(), true) end,
  PLY_SPEED_FOOT = function()
    local ped, pid = PlayerPedId(), PlayerId()
    SetRunSprintMultiplierForPlayer(pid, 1.0)
    SetSwimMultiplierForPlayer(pid, 1.0)
    SetPedMoveRateOverride(ped, 1.0)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
  end,
  PLY_SUPERJUMP = function()
    local ped = PlayerPedId()
    local v = GetEntityVelocity(ped)
    SetEntityVelocity(ped, v.x * 0.2, v.y * 0.2, math.min(v.z, 0.0))
  end,
  MOV_FREECAM = function()
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
  end,
  MOV_NOCLIP_COLLISION = backToGround,
  MOV_NOCLIP_FLOAT = backToGround,
  MOV_NOCLIP_ZVEL = backToGround,
  WPN_DMG_MODIFIER = function()
    local pid, m = PlayerId(), S.server.damageModifier or 1.0
    SetPlayerWeaponDamageModifier(pid, m)
    SetPlayerMeleeWeaponDamageModifier(pid, m)
  end,
  WPN_INFINITE_AMMO = function()
    local ped = PlayerPedId()
    SetPedInfiniteAmmoClip(ped, false)
    SetPedInfiniteAmmo(ped, false, GetSelectedPedWeapon(ped))
  end,
  WPN_GIVE_ALL = function() RemoveAllPedWeapons(PlayerPedId(), true) end,
  VEH_POWER = function()
    local veh = myVehicle()
    if veh then
      SetVehicleCheatPowerIncrease(veh, 1.0)
      ModifyVehicleTopSpeed(veh, 1.0)
    end
  end,
  VEH_GODMODE = function()
    local veh = myVehicle()
    if veh then
      SetEntityInvincible(veh, false)
      SetEntityCanBeDamaged(veh, true)
      SetVehicleCanBeVisiblyDamaged(veh, true)
    end
  end,
  VEH_REPAIR = function(d)
    local veh = myVehicle()
    if veh and d.e0 and d.b0 then
      SetVehicleEngineHealth(veh, d.e0 + 0.0)
      SetVehicleBodyHealth(veh, d.b0 + 0.0)
    end
  end,
  VEH_PLATE = function(d)
    local veh = myVehicle()
    if veh and d.from then SetVehicleNumberPlateText(veh, d.from) end
  end,
}

function S.counter(code, data)
  local fn = ACT[code]
  if not fn or not enabled(code) then return end
  if NEEDS_SHIELD[code] and not S.shieldActive() then return end
  pcall(fn, data)
end

function S.counterEnabled(code)
  return enabled(code)
end
