-- Runs the real client scripts (shared/crypto.lua, client/main.lua, client/heartbeat.lua) under plain
-- Lua 5.4 with stubbed FiveM natives, so the C# tests can verify packets from the actual client code.
--
-- Protocol over stdio (one JSON object per line):
--   stdin  line 1: the init payload JSON the server would send on "jcks_anticheat:init"
--   stdout: {"event": name, "args": [...]} for every TriggerServerEvent
--   stdin  after each heartbeat: the next challenge (ack), or "-" for none
-- arg[1] = resource root, arg[2] = number of heartbeats to emit.

local root, count = arg[1], tonumber(arg[2] or "3")

---------------------------------------------------------------- tiny JSON
local json = {}
do
  local function esc(s)
    return s:gsub('[%c"\\]', function(c)
      local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
      return map[c] or string.format("\\u%04x", c:byte())
    end)
  end
  local function isArray(t)
    local n = 0
    for k in pairs(t) do
      if type(k) ~= "number" then return false end
      n = n + 1
    end
    return n == #t
  end
  function json.encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then
      if math.type(v) == "integer" then return tostring(v) end
      return string.format("%.14g", v)
    elseif t == "string" then return '"' .. esc(v) .. '"'
    elseif t == "table" then
      local out = {}
      if next(v) == nil then return "[]" end
      if isArray(v) then
        for i = 1, #v do out[i] = json.encode(v[i]) end
        return "[" .. table.concat(out, ",") .. "]"
      end
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      for _, k in ipairs(keys) do out[#out + 1] = json.encode(k) .. ":" .. json.encode(v[k]) end
      return "{" .. table.concat(out, ",") .. "}"
    end
    error("cannot encode " .. t)
  end
  function json.decode(s)
    local pos = 1
    local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
    local value
    local function str()
      pos = pos + 1
      local buf = {}
      while true do
        local c = s:sub(pos, pos)
        if c == '"' then pos = pos + 1 break end
        if c == "\\" then
          local e = s:sub(pos + 1, pos + 1)
          local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" }
          if e == "u" then
            buf[#buf + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)); pos = pos + 6
          else
            buf[#buf + 1] = map[e] or e; pos = pos + 2
          end
        else
          buf[#buf + 1] = c; pos = pos + 1
        end
      end
      return table.concat(buf)
    end
    function value()
      ws()
      local c = s:sub(pos, pos)
      if c == "{" then
        pos = pos + 1; local o = {}; ws()
        if s:sub(pos, pos) == "}" then pos = pos + 1 return o end
        while true do
          ws(); local k = str(); ws(); pos = pos + 1
          o[k] = value(); ws()
          local d = s:sub(pos, pos); pos = pos + 1
          if d == "}" then return o end
        end
      elseif c == "[" then
        pos = pos + 1; local a = {}; ws()
        if s:sub(pos, pos) == "]" then pos = pos + 1 return a end
        while true do
          a[#a + 1] = value(); ws()
          local d = s:sub(pos, pos); pos = pos + 1
          if d == "]" then return a end
        end
      elseif c == '"' then return str()
      elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
      elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
      elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
      else
        local num = s:match("^-?[%d%.eE+-]+", pos); pos = pos + #num
        return math.tointeger(tonumber(num)) or tonumber(num)
      end
    end
    return value()
  end
end
_ENV.json = json

---------------------------------------------------------------- scheduler + time
local now = 1000
local threads = {}
function GetGameTimer() return now end
function CreateThread(fn) threads[#threads + 1] = { co = coroutine.create(fn), wakeAt = now } end
function Wait(ms) coroutine.yield(ms or 0) end

local handlers = {}
function RegisterNetEvent(name, fn) if fn then handlers[name] = fn end end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerEvent(name, ...) if handlers[name] then handlers[name](...) end end

local heartbeatsSent = 0
local ackName, ackHandler -- declared before TriggerServerEvent, which reads ackHandler
function TriggerServerEvent(name, ...)
  io.write(json.encode({ event = name, args = { ... } }), "\n")
  io.flush()
  if name ~= "jcks_anticheat:hello" then
    heartbeatsSent = heartbeatsSent + 1
    local ack = io.read("l")
    if ack and ack ~= "-" and ackHandler then ackHandler(ack) end
  end
end

---------------------------------------------------------------- natives used by main/heartbeat
local vec = function(x, y, z) return setmetatable({ x, y, z, x = x, y = y, z = z }, {}) end
function PlayerPedId() return 42 end
function PlayerId() return 0 end
function GetPlayerServerId() return 7 end
function NetworkIsSessionStarted() return true end
function IsPlayerSwitchInProgress() return false end
function IsScreenFadedOut() return false end
function IsScreenFadingIn() return false end
function GetIsLoadingScreenActive() return false end
function IsPedDeadOrDying() return false end
function GetEntityCoords() return vec(100.5, -200.25, 30.0) end
function GetVehiclePedIsIn() return 0 end
function GetEntityHealth() return 200 end
function GetEntityMaxHealth() return 200 end
function GetPedArmour() return 50 end
function GetEntityModel() return 0 end
function GetSelectedPedWeapon() return -1569615261 end
function GetNumResources() return 12 end
function GetHashKey(s) return #s end
function exports(name, fn) end

-- The scanner table may be renamed by scripts/obfuscate.py; find it by shape instead of by name.
local S
local function scanner()
  if S then return S end
  for _, v in pairs(_G) do
    if type(v) == "table" and type(rawget(v, "flag")) == "function" and type(rawget(v, "drainFlags")) == "function" then
      S = v
      return S
    end
  end
end

-- Capture the ack handler the client registers on the random ack event.
local realRegister = RegisterNetEvent
function RegisterNetEvent(name, fn)
  realRegister(name, fn)
  if name == ackName then ackHandler = fn end
end

---------------------------------------------------------------- load the real client code
dofile(root .. "/shared/crypto.lua")
dofile(root .. "/client/main.lua")
dofile(root .. "/client/heartbeat.lua")

local initPayload = io.read("l")
ackName = json.decode(initPayload).ack
handlers["jcks_anticheat:init"](initPayload)

-- Queue a detection so the first heartbeat carries a flag.
assert(scanner(), "scanner table not found")
scanner().flag("PLY_GODMODE_FLAG", { inv = true })

---------------------------------------------------------------- run until enough heartbeats
local guard = 0
while heartbeatsSent < count and guard < 100000 do
  guard = guard + 1
  local nextWake = math.huge
  for _, t in ipairs(threads) do
    if coroutine.status(t.co) ~= "dead" and t.wakeAt <= now then
      local ok, ms = coroutine.resume(t.co)
      if not ok then io.stderr:write("thread error: " .. tostring(ms) .. "\n") os.exit(2) end
      t.wakeAt = now + (ms or 0)
    end
    if coroutine.status(t.co) ~= "dead" and t.wakeAt < nextWake then nextWake = t.wakeAt end
  end
  if nextWake == math.huge then break end
  now = math.max(now + 1, nextWake)
end
