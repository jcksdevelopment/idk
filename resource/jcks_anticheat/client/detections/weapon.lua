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
    S.flag("PLY_GODMODE_PROOFS", { def = defense })
  end

  local weapon = GetSelectedPedWeapon(ped)
  if weapon ~= 0 and not S.allowed("weapons") then
    local perWeapon = GetWeaponDamageModifier(weapon)
    if perWeapon > S.t("weaponDamageModifierMax") then
      S.flag("WPN_DMG_MODIFIER", { w = weapon, wm = math.floor(perWeapon * 100) / 100 })
    end
  end
end)

local ALL_WEAPONS = {
  "WEAPON_KNIFE", "WEAPON_NIGHTSTICK", "WEAPON_HAMMER", "WEAPON_BAT", "WEAPON_GOLFCLUB", "WEAPON_CROWBAR", "WEAPON_BOTTLE",
  "WEAPON_DAGGER", "WEAPON_HATCHET", "WEAPON_KNUCKLE", "WEAPON_MACHETE", "WEAPON_SWITCHBLADE", "WEAPON_WRENCH", "WEAPON_BATTLEAXE",
  "WEAPON_POOLCUE", "WEAPON_STONE_HATCHET", "WEAPON_PISTOL", "WEAPON_PISTOL_MK2", "WEAPON_COMBATPISTOL", "WEAPON_APPISTOL",
  "WEAPON_STUNGUN", "WEAPON_PISTOL50", "WEAPON_SNSPISTOL", "WEAPON_HEAVYPISTOL", "WEAPON_VINTAGEPISTOL", "WEAPON_FLAREGUN",
  "WEAPON_MARKSMANPISTOL", "WEAPON_REVOLVER", "WEAPON_DOUBLEACTION", "WEAPON_CERAMICPISTOL", "WEAPON_NAVYREVOLVER",
  "WEAPON_MICROSMG", "WEAPON_SMG", "WEAPON_SMG_MK2", "WEAPON_ASSAULTSMG", "WEAPON_COMBATPDW", "WEAPON_MACHINEPISTOL",
  "WEAPON_MINISMG", "WEAPON_PUMPSHOTGUN", "WEAPON_SAWNOFFSHOTGUN", "WEAPON_ASSAULTSHOTGUN", "WEAPON_BULLPUPSHOTGUN",
  "WEAPON_MUSKET", "WEAPON_HEAVYSHOTGUN", "WEAPON_DBSHOTGUN", "WEAPON_AUTOSHOTGUN", "WEAPON_ASSAULTRIFLE",
  "WEAPON_ASSAULTRIFLE_MK2", "WEAPON_CARBINERIFLE", "WEAPON_CARBINERIFLE_MK2", "WEAPON_ADVANCEDRIFLE", "WEAPON_SPECIALCARBINE",
  "WEAPON_BULLPUPRIFLE", "WEAPON_COMPACTRIFLE", "WEAPON_MG", "WEAPON_COMBATMG", "WEAPON_GUSENBERG", "WEAPON_SNIPERRIFLE",
  "WEAPON_HEAVYSNIPER", "WEAPON_MARKSMANRIFLE", "WEAPON_RPG", "WEAPON_GRENADELAUNCHER", "WEAPON_MINIGUN", "WEAPON_FIREWORK",
  "WEAPON_RAILGUN", "WEAPON_HOMINGLAUNCHER", "WEAPON_COMPACTLAUNCHER", "WEAPON_GRENADE", "WEAPON_BZGAS", "WEAPON_MOLOTOV",
  "WEAPON_STICKYBOMB", "WEAPON_PROXMINE", "WEAPON_SNOWBALL", "WEAPON_PIPEBOMB", "WEAPON_BALL", "WEAPON_SMOKEGRENADE",
  "WEAPON_FLARE", "WEAPON_PETROLCAN", "WEAPON_FIREEXTINGUISHER",
}
local weaponHashes
S.register("weapon.count", 5000, function()
  if S.allowed("weapons") then return end
  if not weaponHashes then
    weaponHashes = {}
    for i = 1, #ALL_WEAPONS do weaponHashes[i] = GetHashKey(ALL_WEAPONS[i]) end
  end
  local ped, held = PlayerPedId(), 0
  for i = 1, #weaponHashes do
    if HasPedGotWeapon(ped, weaponHashes[i], false) then held = held + 1 end
  end
  if held > (S.server.maxWeapons or 25) then
    S.flag("WPN_GIVE_ALL", { n = held })
  end
end)

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

      local rot = GetGameplayCamRot(2)
      if lastRot then
        local delta = math.max(angleDelta(rot.z, lastRot.z), angleDelta(rot.x, lastRot.x))
        if delta > S.t("aimSnapDegrees") then lastSnapAt = now end
      end
      lastRot = rot
      if shooting and now - lastSnapAt < 150 then
        S.flag("WPN_AIM_SNAP", { ms = now - lastSnapAt })
        lastSnapAt = -100000
      end

      local hasTarget, target = GetEntityPlayerIsFreeAimingAt(pid)
      if hasTarget and target ~= 0 and IsEntityAPed(target) then
        acquiredAt = acquiredAt or now
      else
        acquiredAt = nil
      end
      if shooting then
        if acquiredAt and now - acquiredAt < S.t("triggerbotMs") and now - lastShotAt > 300 then
          fastReactions = fastReactions + 1
        end
        lastShotAt = now
      end
      if now - windowStart > 60000 then fastReactions, windowStart = 0, now end
      if fastReactions >= S.t("triggerbotCount") then
        S.flag("WPN_TRIGGERBOT", { n = fastReactions })
        fastReactions = 0
      end

      local weapon = GetSelectedPedWeapon(ped)
      local _, clip = GetAmmoInClip(ped, weapon)
      if weapon ~= ammoWeapon or clip ~= ammoClip then
        ammoWeapon, ammoClip, ammoShots, ammoStart = weapon, clip, 0, now
      elseif shooting then
        ammoShots = ammoShots + 1
        if ammoShots >= S.t("infiniteAmmoShots") and now - ammoStart > 2000 and GetWeaponDamageType(weapon) == 3 then
          S.flag("WPN_INFINITE_AMMO", { shots = ammoShots, clip = clip })
          ammoShots = 0
        end
      end

      Wait(0)
    end
  end
end)
