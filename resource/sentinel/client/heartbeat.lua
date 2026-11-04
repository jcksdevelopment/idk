-- Encrypted, ratcheting heartbeat.
--
-- Handshake: client fires `sentinel:hello` once; the server answers on `sentinel:init` with a
-- per-session 32-byte key, a challenge, and two event names randomised per server boot (one the
-- server listens on, one the client listens on). After that nothing uses a fixed event name.
--
-- Every 5 s the client sends:
--   seq, nonce, ciphertext = CTR(key, nonce, json{s,c,t,f,st}), mac = HMAC(key, seq|nonce|ciphertext)
-- Then both sides ratchet: key = SHA256(key || mac). A replayed, reordered or forged packet fails
-- MAC verification, and a stopped scanner shows up as a missing heartbeat on the server.

local S = Sentinel
local C = SentinelCrypto

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
  -- 16 bytes. Uniqueness matters for CTR, unpredictability doesn't: seq + timer + counter.
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
    st = snapshot(),
  })
  local nonce = makeNonce()
  local ct = C.ctr(session.key, nonce, plain)
  local seqBytes = string.pack(">I4", session.seq)
  local mac = C.hmac(session.key, seqBytes .. nonce .. ct)

  TriggerServerEvent(session.hbEvent, session.seq, C.toHex(nonce), C.toHex(ct), C.toHex(mac))

  -- Ratchet forward. The server does the same after verifying, so both keys stay in lockstep.
  session.key = C.sha256(session.key .. mac)
end

RegisterNetEvent("sentinel:init", function(payload)
  if S.ready then return end -- the handshake happens exactly once per session
  local data = json.decode(payload)
  if type(data) ~= "table" or type(data.k) ~= "string" then return end

  session.key = C.fromHex(data.k)
  session.challenge = data.c
  session.hbEvent = data.hb
  session.ackEvent = data.ack
  session.interval = data.iv or 5000

  S.server.weaponBlacklist = {}
  for _, name in ipairs(data.wb or {}) do
    S.server.weaponBlacklist[GetHashKey(name)] = name
  end
  S.server.resources = data.rs or {}
  S.server.maxHealth = data.mh or 200
  S.server.damageModifier = data.dm or 1.0
  S.server.graceEvent = data.gr
  S.server.ssRequest = data.sr
  S.server.ssUpload = data.su

  -- Server → client acks carry the next challenge.
  RegisterNetEvent(session.ackEvent, function(nextChallenge)
    if type(nextChallenge) == "string" then session.challenge = nextChallenge end
  end)

  -- Server-authorised grace (heals from a server-side hospital script, admin noclip, etc.).
  if S.server.graceEvent then
    RegisterNetEvent(S.server.graceEvent, function(kind, ms)
      if type(kind) == "string" then S.grant(kind, tonumber(ms) or 5000) end
    end)
  end

  S.ready = true
  TriggerEvent("sentinel:ready")

  CreateThread(function()
    while true do
      local ok, err = pcall(sendHeartbeat)
      if not ok then print(("[sentinel] heartbeat error: %s"):format(err)) end
      Wait(session.interval)
    end
  end)
end)

CreateThread(function()
  while not NetworkIsSessionStarted() do Wait(500) end
  math.randomseed(GetGameTimer() ~ GetPlayerServerId(PlayerId()))
  TriggerServerEvent("sentinel:hello")
end)
