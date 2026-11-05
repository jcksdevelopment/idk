local S = JcksAC

local FIELDS = {
  "fInitialDriveForce", "fInitialDriveMaxFlatVel", "fTractionCurveMax", "fTractionCurveMin",
  "fMass", "fBrakeForce", "fInitialDragCoeff", "fDriveInertia",
}

local lastVeh, lastEngine, lastBody, lastPlate, lastMine
S.register("vehicle.repair", 500, function()
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then lastVeh = nil return end
  local engine, body, plate = GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), GetVehicleNumberPlateText(veh)
  local mine = NetworkGetEntityOwner(veh) == PlayerId()
  if veh == lastVeh and mine and lastMine and not S.allowed("vehicle") then
    if (lastEngine < S.t("repairFromHealth") and engine >= 990) or (lastBody < S.t("repairFromHealth") and body >= 990) then
      S.flag("VEH_REPAIR", { e0 = math.floor(lastEngine), e1 = math.floor(engine), b0 = math.floor(lastBody), b1 = math.floor(body) })
    end
    if lastPlate and plate ~= lastPlate then
      S.flag("VEH_PLATE", { from = lastPlate, to = plate })
    end
  end
  lastVeh, lastEngine, lastBody, lastPlate, lastMine = veh, engine, body, plate, mine
end)

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
    if paintChanges >= S.t("rainbowChanges") then
      S.flag("VEH_RAINBOW", { changes = paintChanges })
      paintChanges = 0
    end
  end
  lastPaint = paint
end)

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
        if S.counterEnabled("VEH_HANDLING") then
          for j = 1, #FIELDS do SetVehicleHandlingFloat(veh, "CHandlingData", FIELDS[j], base[j]) end
        end
        break
      end
    end
  end

  local power = GetVehicleCheatPowerIncrease(veh)
  if power > 1.01 then
    S.flag("VEH_POWER", { p = power })
  end

  if not GetEntityCanBeDamaged(veh) then
    S.flag("VEH_GODMODE", {})
  end

  local top = GetVehicleTopSpeedModifier(veh)
  if top > S.t("topSpeedModifierMax") then
    S.flag("VEH_TOP_SPEED", { p = math.floor(top) })
  end

  local gravity = GetVehicleGravityAmount(veh)
  if math.abs(gravity - 9.8) > S.t("gravityTolerance") then
    S.flag("VEH_GRAVITY", { g = math.floor(gravity * 100) / 100 })
  end

  local ram = GetPlayerVehicleDamageModifier(PlayerId())
  if ram > S.t("vehicleDamageModifierMax") then
    S.flag("VEH_DMG_MODIFIER", { m = math.floor(ram * 100) / 100 })
  end
end)
