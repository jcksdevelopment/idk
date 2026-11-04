-- Sentinel client core: check scheduler, flag queue, grace windows.
-- Detections never call a "ban" event. They push flags into a queue that heartbeat.lua drains into
-- the next encrypted, MAC'd heartbeat. The server decides what a flag is worth.

Sentinel = Sentinel or {}
local S = Sentinel

S.ready = false          -- set once the server's init payload arrives
S.flags = {}             -- pending flags for the next heartbeat
S.lastFlagAt = {}        -- code -> GetGameTimer() of last report (per-code cooldown)
S.grace = {}             -- kind -> GetGameTimer() until which that behaviour is authorised
S.server = {             -- filled from server init
  weaponBlacklist = {},
  resources = {},
  commands = {},
  maxHealth = 200,
}

local checks = {}

--- Register a periodic check. fn() is called every intervalMs from one shared scheduler thread.
function S.register(name, intervalMs, fn)
  checks[#checks + 1] = { name = name, interval = intervalMs, fn = fn, nextAt = 0 }
end

--- Is behaviour `kind` currently authorised (heal, armor, godmode, invisible, noclip, teleport, vision, ragdoll)?
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

--- Queue a detection for the next heartbeat. `data` is a small table of evidence.
function S.flag(code, data)
  local now = GetGameTimer()
  local last = S.lastFlagAt[code]
  if last and now - last < FLAG_COOLDOWN then return end
  S.lastFlagAt[code] = now
  if #S.flags >= MAX_PENDING then table.remove(S.flags, 1) end
  S.flags[#S.flags + 1] = { c = code, t = now, d = data }
end

function S.drainFlags()
  local out = S.flags
  S.flags = {}
  return out
end

-- Grace windows shared by the whole session (loading screens, spawning, respawn).
local function isTransitioning()
  return IsPlayerSwitchInProgress() or IsScreenFadedOut() or IsScreenFadingIn()
    or GetIsLoadingScreenActive() or IsPedDeadOrDying(PlayerPedId(), true)
end
S.isTransitioning = isTransitioning

-- Single scheduler thread: wakes at the next due check, never per-frame.
CreateThread(function()
  while not S.ready do Wait(500) end
  -- Spawn grace: the first 15 seconds after init are noisy (model load, teleport to spawn).
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
            -- A check that throws is either a bug or tampering; report once, keep running.
            S.flag("CHK_ERROR", { n = c.name, e = tostring(err):sub(1, 120) })
          end
        end
        if c.nextAt < nextWake then nextWake = c.nextAt end
      end
    end
    Wait(math.max(50, nextWake - GetGameTimer()))
  end
end)

-- Exports for other client resources (hospital, admin menu, item scripts) to mark behaviour as legit.
-- These are client-side and therefore advisory: the server keeps its own grace via the server export.
exports("GrantGrace", function(kind, ms) S.grant(kind, ms) end)
exports("RevokeGrace", function(kind) S.revoke(kind) end)
