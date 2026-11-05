local S = JcksAC

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
  if proofs >= S.t("godmodeProofs") then
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

S.register("player.tiny", 5000, function()
  if S.allowed("tiny") then return end
  if GetPedConfigFlag(PlayerPedId(), 223, true) then
    S.flag("PLY_TINY_PED", {})
  end
end)

S.register("player.spectate", 3000, function()
  if S.allowed("spectate") or S.allowed("noclip") then return end
  if NetworkIsInSpectatorMode() then
    S.flag("PLY_SPECTATE", {})
  end
end)

do
  local lastHealth, lastArmor
  local HEALTH_JUMP = function() return S.t("healthJump") end
  local ARMOR_JUMP = function() return S.t("armorJump") end

  S.register("player.regen", 500, function()
    local ped = PlayerPedId()
    local health, armor = GetEntityHealth(ped), GetPedArmour(ped)
    if lastHealth and health > lastHealth + HEALTH_JUMP() and not S.allowed("heal") then
      S.flag("PLY_HEALTH_REGEN", { from = lastHealth, to = health })
    end
    if lastArmor and armor > lastArmor + ARMOR_JUMP() and not S.allowed("armor") then
      S.flag("PLY_ARMOR_REGEN", { from = lastArmor, to = armor })
    end
    lastHealth, lastArmor = health, armor
  end)
end

S.register("player.ragdoll", 3000, function()
  local ped = PlayerPedId()
  if S.allowed("ragdoll") or IsPedInAnyVehicle(ped, false) then return end
  if not CanPedRagdoll(ped) then
    S.flag("PLY_NO_RAGDOLL", {})
  end
end)

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
    if horizontal > S.t("footSpeed") and not IsPedSwimmingUnderWater(ped) and not S.allowed("teleport") then
      S.flag("PLY_SPEED_FOOT", { v = math.floor(horizontal * 10) / 10 })
    end

    if IsPedJumping(ped) then
      jumpActive = true
      local h = GetEntityHeightAboveGround(ped)
      if h > jumpPeak then jumpPeak = h end
      if vel.z > S.t("superjumpVelocity") then
        S.flag("PLY_SUPERJUMP", { vz = math.floor(vel.z * 10) / 10 })
      end
    elseif jumpActive then
      if jumpPeak > S.t("superjumpHeight") then
        S.flag("PLY_SUPERJUMP", { peak = math.floor(jumpPeak * 10) / 10 })
      end
      jumpActive, jumpPeak = false, 0.0
    end
  end)
end

do
  local sprintStart
  S.register("player.stamina", 1000, function()
    local ped, pid = PlayerPedId(), PlayerId()
    if IsPedSprinting(ped) and GetPlayerSprintStaminaRemaining(pid) <= 0.0 then
      sprintStart = sprintStart or GetGameTimer()
      if GetGameTimer() - sprintStart > S.t("staminaSeconds") * 1000 then
        S.flag("PLY_STAMINA", { ms = GetGameTimer() - sprintStart })
        sprintStart = GetGameTimer()
      end
    else
      sprintStart = nil
    end
  end)
end

CreateThread(function()
  while not S.ready do Wait(500) end
  local wasDead = false
  while true do
    Wait(400)
    local ped = PlayerPedId()
    local dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
    if wasDead and not dead and not S.allowed("heal") and not S.allowed("revive") then
      S.flag("PLY_SELF_REVIVE", {})
    end
    wasDead = dead
  end
end)
