-- Vehicle detections: handling edits, power/torque boost, vehicle godmode.
-- Spawn bypass is judged on the server via entityCreating (EntityValidator).

local S = JcksAC

local FIELDS = {
  "fInitialDriveForce", "fInitialDriveMaxFlatVel", "fTractionCurveMax", "fTractionCurveMin",
  "fMass", "fBrakeForce", "fInitialDragCoeff", "fDriveInertia",
}

-- Instant repair and plate swaps (menu "fix vehicle" / "change plate"). Mechanic and garage
-- scripts should grant exports.jcks_anticheat:GrantGrace("vehicle", ms) or the server-side export.
local lastVeh, lastEngine, lastBody, lastPlate
S.register("vehicle.repair", 500, function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then lastVeh = nil return end
  local engine, body, plate = GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), GetVehicleNumberPlateText(veh)
  if veh == lastVeh and not S.allowed("vehicle") then
    -- A badly damaged vehicle snapping back to (near) full health in half a second.
    if (lastEngine < 600 and engine >= 990) or (lastBody < 600 and body >= 990) then
      S.flag("VEH_REPAIR", { e0 = math.floor(lastEngine), e1 = math.floor(engine), b0 = math.floor(lastBody), b1 = math.floor(body) })
    end
    if lastPlate and plate ~= lastPlate then
      S.flag("VEH_PLATE", { from = lastPlate, to = plate })
    end
  end
  lastVeh, lastEngine, lastBody, lastPlate = veh, engine, body, plate
end)

-- Rainbow vehicle: the paint colour changing many times in a few seconds (menu "rainbow paint").
-- Paint shops change it a handful of times while browsing; a menu cycles it every frame.
local paintChanges, paintWindowStart, lastPaint = 0, 0, nil
S.register("vehicle.rainbow", 250, function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or S.allowed("vehicle") then lastPaint = nil return end
  local r, g, b = GetVehicleCustomPrimaryColour(veh)
  local p1, p2 = GetVehicleColours(veh)
  local paint = table.concat({ r, g, b, p1, p2 }, ",")
  local now = GetGameTimer()
  if now - paintWindowStart > 5000 then paintChanges, paintWindowStart = 0, now end
  if lastPaint and paint ~= lastPaint then
    paintChanges = paintChanges + 1
    if paintChanges >= 12 then
      S.flag("VEH_RAINBOW", { changes = paintChanges })
      paintChanges = 0
    end
  end
  lastPaint = paint
end)

-- First handling values seen for each model this session. Handling is per-model in GTA, so a
-- menu that edits one car's handling changes what every later car of that model reads too;
-- comparing against the first observation catches edits made after we started watching.
local baseline = {}

local function readHandling(veh)
  local out = {}
  for i = 1, #FIELDS do
    out[i] = GetVehicleHandlingFloat(veh, "CHandlingData", FIELDS[i])
  end
  return out
end

S.register("vehicle.state", 1500, function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
  if S.allowed("vehicle") then return end

  local model = GetEntityModel(veh)
  local now = readHandling(veh)
  local base = baseline[model]
  if not base then
    baseline[model] = now
  else
    for i = 1, #FIELDS do
      local b, v = base[i], now[i]
      local tolerance = math.max(0.01, math.abs(b) * 0.02)
      if math.abs(v - b) > tolerance then
        S.flag("VEH_HANDLING", { f = FIELDS[i], b = b, v = v })
        break
      end
    end
  end

  local power = GetVehicleCheatPowerIncrease(veh)
  if power > 1.01 then
    S.flag("VEH_POWER", { p = power })
  end

  -- Bulletproof tyres are a normal tuning option, so only the damage flag itself is checked.
  if not GetEntityCanBeDamaged(veh) then
    S.flag("VEH_GODMODE", {})
  end
end)
