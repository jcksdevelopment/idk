JcksAC = JcksAC or {}
local S = JcksAC

S.ready = false
S.flags = {}
S.lastFlagAt = {}
S.grace = {}
S.server = {
  weaponBlacklist = {},
  resources = {},
  commands = {},
  maxHealth = 200,
}

local DEFAULTS = {
  freecamGameplayDistance = 30,
  freecamDistance = 50,
  freecamSeconds = 8,
  noclipRiseSpeed = 15,
  noclipFloatHeight = 5,
  noclipFloatSeconds = 3,
  godmodeProofs = 2,
  healthJump = 25,
  armorJump = 10,
  footSpeed = 12,
  superjumpVelocity = 9,
  superjumpHeight = 3.5,
  staminaSeconds = 25,
  repairFromHealth = 600,
  rainbowChanges = 12,
  aimSnapDegrees = 70,
  triggerbotMs = 60,
  triggerbotCount = 5,
  infiniteAmmoShots = 10,
  topSpeedModifierMax = 100,
  gravityTolerance = 2,
  vehicleDamageModifierMax = 1.5,
  weaponDamageModifierMax = 1.5,
  scanIntervalScale = 1,
  espBlipPlayers = 4,
  defenseModifierMin = 0.5,
}

function S.t(name)
  local v = S.server.thresholds and S.server.thresholds[name]
  if type(v) == "number" then return v end
  return DEFAULTS[name]
end

local checks = {}

local resets = {}
function S.onReset(fn) resets[#resets + 1] = fn end

function S.register(name, intervalMs, fn)
  checks[#checks + 1] = { name = name, interval = intervalMs, fn = fn, nextAt = 0 }
end

S.held = {}

function S.allowed(kind)
  local now = GetGameTimer()
  local untilAt = S.grace[kind]
  if untilAt ~= nil and now < untilAt then return true end
  local heldUntil = S.held[kind]
  return heldUntil ~= nil and now < heldUntil
end

function S.hold(kind)
  S.held[kind] = GetGameTimer() + 1800000
end

function S.release(kind)
  if S.held[kind] and not (S.grace[kind] and GetGameTimer() < S.grace[kind]) then S.held[kind] = nil end
end

function S.grant(kind, ms)
  local untilAt = GetGameTimer() + (ms or 5000)
  if (S.grace[kind] or 0) < untilAt then S.grace[kind] = untilAt end
end

function S.revoke(kind)
  S.grace[kind] = nil
end

local FLAG_COOLDOWN = 10000
local MAX_PENDING = 32

function S.flag(code, data)
  if S.server.ignore and S.server.ignore[code] then return end
  if S.counter then S.counter(code, data or {}) end
  local now = GetGameTimer()
  local last = S.lastFlagAt[code]
  if last and now - last < FLAG_COOLDOWN then return end
  S.lastFlagAt[code] = now
  if #S.flags >= MAX_PENDING then table.remove(S.flags, 1) end
  S.flags[#S.flags + 1] = { c = code, t = now, d = data }
end

S.uses = {}
function S.queueUse(resource, kind, allowed)
  if not allowed and not S.server.integrationLearning and not S.server.integrationTrustAll then return end
  if #S.uses >= 32 then return end
  for i = 1, #S.uses do
    local u = S.uses[i]
    if u.r == resource and u.k == kind then return end
  end
  S.uses[#S.uses + 1] = { r = resource, k = kind, a = allowed }
end

function S.drainUses()
  local out = S.uses
  S.uses = {}
  return out
end

function S.drainFlags()
  local out = S.flags
  S.flags = {}
  return out
end

local function isTransitioning()
  return IsPlayerSwitchInProgress() or IsScreenFadedOut() or IsScreenFadingIn()
    or GetIsLoadingScreenActive() or IsPedDeadOrDying(PlayerPedId(), true)
end
S.isTransitioning = isTransitioning

CreateThread(function()
  while not S.ready do Wait(500) end
  S.grant("teleport", 15000); S.grant("heal", 15000); S.grant("armor", 15000)

  while true do
    local now = GetGameTimer()
    local nextWake = now + 1000
    if isTransitioning() then
      for i = 1, #resets do pcall(resets[i]) end
    else
      for i = 1, #checks do
        local c = checks[i]
        if now >= c.nextAt then
          c.nextAt = now + math.floor(c.interval * math.min(4, math.max(0.5, S.t("scanIntervalScale"))))
          local ok, err = pcall(c.fn)
          if not ok then
            S.flag("CHK_ERROR", { n = c.name, e = tostring(err):sub(1, 120) })
          end
        end
        if c.nextAt < nextWake then nextWake = c.nextAt end
      end
    end
    Wait(math.max(50, nextWake - GetGameTimer()))
  end
end)

exports("GrantGrace", function(kind, ms) S.grant(kind, ms) end)
exports("RevokeGrace", function(kind) S.revoke(kind) end)
