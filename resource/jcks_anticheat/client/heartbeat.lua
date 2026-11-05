local S = JcksAC
local C = JcksCrypto

local session = {
  key = nil,
  seq = 0,
  challenge = "",
  hbEvent = nil,
  ackEvent = nil,
  interval = 5000,
}

local nonceCounter = 0
local function makeNonce()
  nonceCounter = nonceCounter + 1
  return string.pack(">I4I4I4I4", session.seq & 0xffffffff, GetGameTimer() & 0xffffffff,
    nonceCounter & 0xffffffff, math.random(0, 0x7fffffff))
end

local function snapshot()
  local ped = PlayerPedId()
  local x, y, z = table.unpack(GetEntityCoords(ped))
  local veh = GetVehiclePedIsIn(ped, false)
  return {
    h = GetEntityHealth(ped),
    mh = GetEntityMaxHealth(ped),
    a = GetPedArmour(ped),
    p = { math.floor(x * 10) / 10, math.floor(y * 10) / 10, math.floor(z * 10) / 10 },
    v = veh ~= 0 and GetEntityModel(veh) or 0,
    w = GetSelectedPedWeapon(ped),
    r = GetNumResources(),
  }
end

local function sendHeartbeat()
  session.seq = session.seq + 1
  local plain = json.encode({
    s = session.seq,
    c = session.challenge,
    t = GetGameTimer(),
    f = S.drainFlags(),
    u = S.drainUses(),
    st = snapshot(),
  })
  local nonce = makeNonce()
  local ct = C.ctr(session.key, nonce, plain)
  local seqBytes = string.pack(">I4", session.seq)
  local mac = C.hmac(session.key, seqBytes .. nonce .. ct)

  TriggerServerEvent(session.hbEvent, session.seq, C.toHex(nonce), C.toHex(ct), C.toHex(mac))

  session.key = C.sha256(session.key .. mac)
end

local function applySettings(data)
  S.server.weaponBlacklist = {}
  for _, name in ipairs(data.wb or {}) do
    S.server.weaponBlacklist[GetHashKey(name)] = name
  end
  S.server.maxHealth = data.mh or 200
  S.server.damageModifier = data.dm or 1.0
  S.server.ignore = {}
  for _, code in ipairs(data.ig or {}) do S.server.ignore[code] = true end
  if data.iv then session.interval = data.iv end
  S.server.maxWeapons = data.mw or 25
  S.server.thresholds = data.ct or {}
  S.server.integrations = {}
  for resource, kinds in pairs(data.it or {}) do
    local set = {}
    for _, k in ipairs(kinds) do set[k] = true end
    S.server.integrations[resource] = set
  end
  S.server.integrationGraceMs = data.ig2 or 5000
  S.server.integrationLearning = data.il and true or false
  S.server.integrationTrustAll = data.ita ~= false
  S.server.countermeasures = data.cm and true or false
  S.server.cmSkip = {}
  for _, code in ipairs(data.cs or {}) do S.server.cmSkip[code] = true end
  if data.bp ~= nil then S.server.bypass = data.bp and true or false end
  if data.bc then
    S.server.bypassCodes = {}
    for _, code in ipairs(data.bc) do S.server.bypassCodes[code] = true end
  end
  S.server.textureBlacklist = data.tb or {}
end

RegisterNetEvent("jcks_anticheat:init", function(payload)
  if S.ready then return end
  local data = json.decode(payload)
  if type(data) ~= "table" or type(data.k) ~= "string" then return end

  session.key = C.fromHex(data.k)
  session.challenge = data.c
  session.hbEvent = data.hb
  session.ackEvent = data.ack
  session.interval = data.iv or 5000

  applySettings(data)
  S.server.resources = data.rs or {}
  S.server.graceEvent = data.gr
  S.server.ssRequest = data.sr
  S.server.ssUpload = data.su
  S.server.panelEvent = data.po

  if data.se then
    RegisterNetEvent(data.se, function(raw)
      local d = json.decode(raw)
      if type(d) == "table" then applySettings(d) end
    end)
  end

  if data.ru then
    RegisterNetEvent(data.ru, function(name)
      if type(name) == "string" then S.server.resources[#S.server.resources + 1] = name end
    end)
  end

  RegisterNetEvent(session.ackEvent, function(nextChallenge)
    if type(nextChallenge) == "string" then session.challenge = nextChallenge end
  end)

  if S.server.graceEvent then
    RegisterNetEvent(S.server.graceEvent, function(kind, ms)
      if type(kind) == "string" then S.grant(kind, tonumber(ms) or 5000) end
    end)
  end

  S.ready = true
  TriggerEvent("jcks_anticheat:ready")

  local lastSent, nextDue = 0, 0
  local function send()
    lastSent = GetGameTimer()
    nextDue = lastSent + session.interval
    local ok, err = pcall(sendHeartbeat)
    if not ok then print(("[jcks_anticheat] heartbeat error: %s"):format(err)) end
  end

  function S.sendNow()
    if GetGameTimer() - lastSent >= 400 then send() end
  end

  CreateThread(function()
    while true do
      if GetGameTimer() >= nextDue then send() end
      Wait(math.max(50, nextDue - GetGameTimer()))
    end
  end)
end)

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  math.randomseed(GetGameTimer() ~ GetPlayerServerId(PlayerId()))
  TriggerServerEvent("jcks_anticheat:hello")
end)
