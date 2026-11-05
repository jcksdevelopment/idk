-- Movement detections: freecam, noclip (collision flag, floating, impossible vertical velocity).
-- Teleport and vehicle speed are judged by the server (MovementValidator), where the client can't lie.

local S = JcksAC

local function vdist(a, b)
  local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local AIRCRAFT = { [15] = true, [16] = true } -- helicopters, planes

local function inAircraft(ped)
  local veh = GetVehiclePedIsIn(ped, false)
  return veh ~= 0 and AIRCRAFT[GetVehicleClass(veh)] == true
end

-- Freecam: the camera drifts far from the ped.
--  * Gameplay cam far from ped with no scripted cam rendering: the gameplay cam itself was moved.
--  * Final rendered cam (which includes scripted cams, how most freecams work) far from ped for
--    a sustained period. Short scripted cams (shops, garages, char creator) are tolerated; long
--    legit ones should call exports.jcks_anticheat:GrantGrace("camera", ms).
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
    if gameplay > 30.0 and GetRenderingCam() == -1 and not IsPedInAnyVehicle(ped, false) then
      S.flag("MOV_FREECAM", { d = math.floor(gameplay), kind = "gameplay" })
    end

    local rendered = vdist(GetFinalRenderedCamCoord(), pos)
    if rendered > 50.0 then
      farSince = farSince or GetGameTimer()
      if GetGameTimer() - farSince > 8000 then
        S.flag("MOV_FREECAM", { d = math.floor(rendered), kind = "rendered" })
        farSince = GetGameTimer()
      end
    else
      farSince = nil
    end
  end)
end

-- NoClip: collision disabled, floating in the air, or rising faster than physics allows.
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
    if IsPedInParachuteFreeFall(ped) or GetPedParachuteState(ped) >= 0 or IsPedClimbing(ped)
        or IsPedSwimming(ped) or IsEntityAttached(subject) then
      floatSince = nil
      return
    end

    local vel = GetEntityVelocity(subject)
    if veh == 0 and vel.z > 15.0 then
      S.flag("MOV_NOCLIP_ZVEL", { vz = math.floor(vel.z * 10) / 10 })
    end

    local height = GetEntityHeightAboveGround(subject)
    if height > 5.0 and math.abs(vel.z) < 0.5 and not IsPedFalling(ped) then
      floatSince = floatSince or GetGameTimer()
      if GetGameTimer() - floatSince > 3000 then
        S.flag("MOV_NOCLIP_FLOAT", { h = math.floor(height), veh = veh ~= 0 })
        floatSince = GetGameTimer()
      end
    else
      floatSince = nil
    end
  end)
end
