-- Weapon detections: blacklisted weapons, damage modifiers, aim snapping, triggerbot, infinite ammo.
-- Range, silent aim, rapid fire, headshot ratio and explosive ammo are judged on the server from
-- weaponDamageEvent / explosionEvent, which the client can't rewrite after the fact.

local S = JcksAC

S.register("weapon.inventory", 2500, function()
  local ped, pid = PlayerPedId(), PlayerId()

  for hash, name in pairs(S.server.weaponBlacklist) do
    if HasPedGotWeapon(ped, hash, false) then
      S.flag("WPN_BLACKLIST", { w = name })
      RemoveWeaponFromPed(ped, hash)
    end
  end

  local expected = S.server.damageModifier or 1.0
  local dmg = GetPlayerWeaponDamageModifier(pid)
  local melee = GetPlayerMeleeWeaponDamageModifier(pid)
  local defense = GetPlayerWeaponDefenseModifier(pid)
  if math.abs(dmg - expected) > 0.05 or math.abs(melee - expected) > 0.05 then
    S.flag("WPN_DMG_MODIFIER", { d = dmg, m = melee })
  end
  if defense < 0.95 and not S.allowed("godmode") then
    -- A lowered defense modifier means incoming damage is scaled down: a semi-godmode.
    S.flag("PLY_GODMODE_PROOFS", { def = defense })
  end
end)

-- Per-frame sampling, only while the player is armed and aiming or shooting. Otherwise this thread
-- sleeps 250 ms, so the idle cost is effectively zero.
CreateThread(function()
  while not S.ready do Wait(500) end

  local lastRot, lastSnapAt = nil, -100000
  local acquiredAt, lastShotAt = nil, -100000
  local fastReactions, windowStart = 0, GetGameTimer()
  local ammoClip, ammoShots, ammoStart, ammoWeapon = nil, 0, nil, nil

  local function angleDelta(a, b)
    local d = math.abs(a - b) % 360.0
    return d > 180.0 and 360.0 - d or d
  end

  while true do
    local ped, pid = PlayerPedId(), PlayerId()
    local aiming = IsPlayerFreeAiming(pid)
    local shooting = IsPedShooting(ped)

    if not (aiming or shooting) or S.isTransitioning() then
      lastRot, acquiredAt, ammoClip = nil, nil, nil
      Wait(250)
    else
      local now = GetGameTimer()

      -- Aim snap: huge camera rotation in one frame, followed by a shot within 150 ms.
      local rot = GetGameplayCamRot(2)
      if lastRot then
        local delta = math.max(angleDelta(rot.z, lastRot.z), angleDelta(rot.x, lastRot.x))
        if delta > 70.0 then lastSnapAt = now end
      end
      lastRot = rot
      if shooting and now - lastSnapAt < 150 then
        S.flag("WPN_AIM_SNAP", { ms = now - lastSnapAt })
        lastSnapAt = -100000
      end

      -- Triggerbot: a shot fired < 60 ms after the crosshair lands on a ped, repeatedly.
      local hasTarget, target = GetEntityPlayerIsFreeAimingAt(pid)
      if hasTarget and target ~= 0 and IsEntityAPed(target) then
        acquiredAt = acquiredAt or now
      else
        acquiredAt = nil
      end
      if shooting then
        if acquiredAt and now - acquiredAt < 60 and now - lastShotAt > 300 then
          fastReactions = fastReactions + 1
        end
        lastShotAt = now
      end
      if now - windowStart > 60000 then fastReactions, windowStart = 0, now end
      if fastReactions >= 5 then
        S.flag("WPN_TRIGGERBOT", { n = fastReactions })
        fastReactions = 0
      end

      -- Infinite ammo: >= 10 shots with an unchanging clip count.
      local weapon = GetSelectedPedWeapon(ped)
      local _, clip = GetAmmoInClip(ped, weapon)
      if weapon ~= ammoWeapon or clip ~= ammoClip then
        ammoWeapon, ammoClip, ammoShots, ammoStart = weapon, clip, 0, now
      elseif shooting then
        ammoShots = ammoShots + 1
        if ammoShots >= 10 and now - ammoStart > 2000 and GetWeaponDamageType(weapon) == 3 then
          S.flag("WPN_INFINITE_AMMO", { shots = ammoShots, clip = clip })
          ammoShots = 0
        end
      end

      Wait(0)
    end
  end
end)
