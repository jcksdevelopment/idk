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

local checks = {}

function S.register(name, intervalMs, fn)
  checks[#checks + 1] = { name = name, interval = intervalMs, fn = fn, nextAt = 0 }
end

function S.allowed(kind)
  local untilAt = S.grace[kind]
  return untilAt ~= nil and GetGameTimer() < untilAt
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
  if not allowed and not S.server.integrationLearning then return end
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
    if not isTransitioning() then
      for i = 1, #checks do
        local c = checks[i]
        if now >= c.nextAt then
          c.nextAt = now + c.interval
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
