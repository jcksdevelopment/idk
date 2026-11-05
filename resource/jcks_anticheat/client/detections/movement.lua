local S = JcksAC

local function vdist(a, b)
  local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local AIRCRAFT = { [15] = true, [16] = true }

local function inAircraft(ped)
  local veh = GetVehiclePedIsIn(ped, false)
  return veh ~= 0 and AIRCRAFT[GetVehicleClass(veh)] == true
end

do
  local farSince
  S.register("movement.freecam", 1000, function()
    local ped = PlayerPedId()
    if S.allowed("noclip") or S.allowed("camera") or IsCutsceneActive() or IsPlayerSwitchInProgress()
        or NetworkIsInSpectatorMode() then
      farSince = nil
      return
    end
    local pos = GetEntityCoords(ped)
    local gameplay = vdist(GetGameplayCamCoord(), pos)
    if gameplay > S.t("freecamGameplayDistance") and GetRenderingCam() == -1 and not IsPedInAnyVehicle(ped, false) then
      S.flag("MOV_FREECAM", { d = math.floor(gameplay), kind = "gameplay" })
    end

    local rendered = vdist(GetFinalRenderedCamCoord(), pos)
    if rendered > S.t("freecamDistance") then
      farSince = farSince or GetGameTimer()
      if GetGameTimer() - farSince > S.t("freecamSeconds") * 1000 then
        S.flag("MOV_FREECAM", { d = math.floor(rendered), kind = "rendered" })
        farSince = GetGameTimer()
      end
    else
      farSince = nil
    end
  end)
end

do
  local floatSince
  S.register("movement.noclip", 500, function()
    if S.allowed("noclip") then floatSince = nil return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local subject = veh ~= 0 and veh or ped

    if GetEntityCollisionDisabled(subject) then
      S.flag("MOV_NOCLIP_COLLISION", { veh = veh ~= 0 })
    end

    if veh ~= 0 and inAircraft(ped) then floatSince = nil return end
    if IsPedInParachuteFreeFall(ped) or GetPedParachuteState(ped) > 0 or IsPedClimbing(ped)
        or IsPedSwimming(ped) or IsEntityAttached(subject) then
      floatSince = nil
      return
    end

    local vel = GetEntityVelocity(subject)
    if veh == 0 and vel.z > S.t("noclipRiseSpeed") then
      S.flag("MOV_NOCLIP_ZVEL", { vz = math.floor(vel.z * 10) / 10 })
    end

    local height = GetEntityHeightAboveGround(subject)
    if height < 3.0 and math.abs(vel.z) < 2.0 and not GetEntityCollisionDisabled(subject) then
      local c = GetEntityCoords(subject)
      S.lastGround = { x = c.x, y = c.y, z = c.z }
    end
    if height > S.t("noclipFloatHeight") and math.abs(vel.z) < 0.5 and not IsPedFalling(ped) then
      floatSince = floatSince or GetGameTimer()
      if GetGameTimer() - floatSince > S.t("noclipFloatSeconds") * 1000 then
        S.flag("MOV_NOCLIP_FLOAT", { h = math.floor(height), veh = veh ~= 0 })
        floatSince = GetGameTimer()
      end
    else
      floatSince = nil
    end
  end)
end
