-- Player-state detections: godmode, proofs, health/armour regen, no-ragdoll, superjump,
-- on-foot speedhack, infinite stamina, thermal/night vision, invisibility.

local S = JcksAC

-- Godmode / proofs / invisibility: cheap state reads, every 2 s.
S.register("player.state", 2000, function()
  local ped, pid = PlayerPedId(), PlayerId()
  if S.allowed("godmode") then return end

  if GetPlayerInvincible(pid) or GetPlayerInvincible_2(pid) or not GetEntityCanBeDamaged(ped) then
    S.flag("PLY_GODMODE_FLAG", { inv = GetPlayerInvincible(pid), dmg = GetEntityCanBeDamaged(ped) })
  end

  local _, bullet, fire, explosion, collision, melee, steam, p7, drown = GetEntityProofs(ped)
  local proofs = 0
  for _, v in ipairs({ bullet, fire, explosion, melee, steam, drown }) do
    if v == 1 or v == true then proofs = proofs + 1 end
  end
  if proofs >= 2 then
    S.flag("PLY_GODMODE_PROOFS", { n = proofs })
  end

  local health, maxHealth = GetEntityHealth(ped), GetEntityMaxHealth(ped)
  if health > maxHealth + 1 or maxHealth > S.server.maxHealth then
    S.flag("PLY_HEALTH_CAP", { h = health, mh = maxHealth })
  end

  if not S.allowed("invisible") and not IsPedInAnyVehicle(ped, false)
      and (not IsEntityVisible(ped) or GetEntityAlpha(ped) < 50) then
    S.flag("PLY_INVISIBLE", { vis = IsEntityVisible(ped), a = GetEntityAlpha(ped) })
  end

  if not S.allowed("vision") and (GetUsingseethrough() or GetUsingnightvision()) then
    S.flag("PLY_VISION", { th = GetUsingseethrough(), nv = GetUsingnightvision() })
  end
end)

-- Spectating other players (menus' "spectate player" option) without an admin grant.
S.register("player.spectate", 3000, function()
  if S.allowed("spectate") or S.allowed("noclip") then return end
  if NetworkIsInSpectatorMode() then
    S.flag("PLY_SPECTATE", {})
  end
end)

-- Health / armour regeneration: sample every 500 ms, compare against natural regen.
do
  local lastHealth, lastArmor
  -- GTA natural regen tops out around 1 hp per ~1-2 s, and only up to half health.
  local HEALTH_JUMP = 25
  local ARMOR_JUMP = 10

  S.register("player.regen", 500, function()
    local ped = PlayerPedId()
    local health, armor = GetEntityHealth(ped), GetPedArmour(ped)
    if lastHealth and health > lastHealth + HEALTH_JUMP and not S.allowed("heal") then
      S.flag("PLY_HEALTH_REGEN", { from = lastHealth, to = health })
    end
    if lastArmor and armor > lastArmor + ARMOR_JUMP and not S.allowed("armor") then
      S.flag("PLY_ARMOR_REGEN", { from = lastArmor, to = armor })
    end
    lastHealth, lastArmor = health, armor
  end)
end

-- No ragdoll: every 3 s.
S.register("player.ragdoll", 3000, function()
  local ped = PlayerPedId()
  if S.allowed("ragdoll") or IsPedInAnyVehicle(ped, false) then return end
  if not CanPedRagdoll(ped) then
    S.flag("PLY_NO_RAGDOLL", {})
  end
end)

-- Superjump + on-foot speed, sampled every 250 ms while on foot.
do
  local jumpPeak, jumpActive = 0.0, false
  S.register("player.motion", 250, function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsPedFalling(ped)
        or IsPedInParachuteFreeFall(ped) or GetPedParachuteState(ped) >= 0 then
      jumpActive = false
      return
    end

    local vel = GetEntityVelocity(ped)
    local horizontal = math.sqrt(vel.x * vel.x + vel.y * vel.y)
    if horizontal > 12.0 and not IsPedSwimmingUnderWater(ped) and not S.allowed("teleport") then
      S.flag("PLY_SPEED_FOOT", { v = math.floor(horizontal * 10) / 10 })
    end

    if IsPedJumping(ped) then
      jumpActive = true
      local h = GetEntityHeightAboveGround(ped)
      if h > jumpPeak then jumpPeak = h end
      if vel.z > 9.0 then
        S.flag("PLY_SUPERJUMP", { vz = math.floor(vel.z * 10) / 10 })
      end
    elseif jumpActive then
      if jumpPeak > 3.5 then
        S.flag("PLY_SUPERJUMP", { peak = math.floor(jumpPeak * 10) / 10 })
      end
      jumpActive, jumpPeak = false, 0.0
    end
  end)
end

-- Infinite stamina: sprinting continuously with stamina pinned at 100.
do
  local sprintStart
  S.register("player.stamina", 1000, function()
    local ped, pid = PlayerPedId(), PlayerId()
    if IsPedSprinting(ped) and GetPlayerSprintStaminaRemaining(pid) <= 0.0 then
      -- GetPlayerSprintStaminaRemaining is "stamina used"; 0 means full tank.
      sprintStart = sprintStart or GetGameTimer()
      if GetGameTimer() - sprintStart > 25000 then
        S.flag("PLY_STAMINA", { ms = GetGameTimer() - sprintStart })
        sprintStart = GetGameTimer()
      end
    else
      sprintStart = nil
    end
  end)
end
