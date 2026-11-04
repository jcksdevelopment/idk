-- Vehicle detections: handling edits, power/torque boost, vehicle godmode.
-- Spawn bypass is judged on the server via entityCreating (EntityValidator).

local S = Sentinel

local FIELDS = {
  "fInitialDriveForce", "fInitialDriveMaxFlatVel", "fTractionCurveMax", "fTractionCurveMin",
  "fMass", "fBrakeForce", "fInitialDragCoeff", "fDriveInertia",
}

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
