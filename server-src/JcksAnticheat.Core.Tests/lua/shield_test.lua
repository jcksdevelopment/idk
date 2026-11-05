-- Runs resource/jcks_anticheat/shield/shield.lua in a simulated resource state and checks what it reports.
-- arg[1] = resource root. Prints "SHIELD OK" when every expectation holds.
local root = arg[1]
local reports = {}
local started = { testres = true, jcks_anticheat = true, ox_lib = true }
local threads = {}

function GetCurrentResourceName() return "testres" end
function GetResourceState(r) return started[r] and "started" or "missing" end
function TriggerEvent(name, res, kind, detail) if name == "jcks_anticheat:shield" and kind ~= "hello" then reports[#reports + 1] = kind .. "|" .. detail.fn end end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
local calls = 0
function TriggerServerEvent() calls = calls + 1 end
function CreateVehicle() calls = calls + 1 return 7 end
function SetEntityCoords() calls = calls + 1 end
Citizen = { InvokeNative = function() calls = calls + 1 end }

-- FiveM runs resource code inside scheduler coroutines, so the stack the shield walks holds only
-- that code's frames. Do the same here, or the test harness's own frames would look injected.
local function loadAs(code, chunkname)
  local co = coroutine.create(assert(load(code, chunkname)))
  local ok, err = coroutine.resume(co)
  assert(ok, err)
end
local f = assert(io.open(root .. "/shield/shield.lua")):read("a")
loadAs(f, "@@jcks_anticheat/shield/shield.lua")

local function resumeAll() for _, co in ipairs(threads) do coroutine.resume(co) end end
local function expect(cond, msg) if not cond then print("FAIL: " .. msg) os.exit(1) end end
local function count() return #reports end

-- Legitimate resource code (FiveM names file chunks "@@resource/path").
loadAs([[ function Helper(cb) cb() end
          function Helper2() TriggerServerEvent("bank:deposit", 5) end
          TriggerServerEvent("legit:event") CreateVehicle(1) ]], "@@testres/client/main.lua")
loadAs([[ SetEntityCoords(1, 0, 0, 0) Citizen.InvokeNative(0x1234) ]], "@@ox_lib/imports/teleport/client.lua")
expect(count() == 0, "legit code reported: " .. table.concat(reports, ","))
expect(calls == 4, "wrappers must still call the originals (calls=" .. calls .. ")")

-- Executor-style injection: code with no file behind it.
loadAs([[ TriggerServerEvent("esx:giveMoney", 999999) ]], "=(load)")
expect(reports[1] == "call|TriggerServerEvent", "plain injected call not reported")

-- Chunk named after a resource that isn't running.
loadAs([[ CreateVehicle(2) ]], "@@totally_legit_menu/main.lua")
expect(reports[2] == "call|CreateVehicle", "fake resource chunk not reported")

-- Injected code hiding behind the resource's own helpers.
loadAs([[ Helper(function() SetEntityCoords(1, 9, 9, 9) end) ]], "menu")
expect(reports[3] == "call|SetEntityCoords", "injected callback via legit helper not reported")
loadAs([[ Helper2() ]], "menu2")
expect(#reports == 4 and reports[4]:find("TriggerServerEvent"), "injected frame deeper in the stack not reported")

-- Global trap: snapshot after the 15 s settle, then a menu defines globals and swaps a wrapper out.
resumeAll()                               -- starts the thread: parks in Wait(15000)
resumeAll()                               -- settle over: snapshots known globals, parks in Wait(10000)
local before = count()
loadAs([[ function OpenModMenu() end ]], "=(executor)")
_G.CreateVehicle = function() end         -- tamper: wrapper replaced
resumeAll()                               -- past Wait(10000): scan
local kinds = table.concat(reports, ",", before + 1)
expect(kinds:find("global|OpenModMenu"), "injected global function not reported: " .. kinds)
expect(kinds:find("tamper|CreateVehicle"), "wrapper replacement not reported: " .. kinds)

-- Each finding is reported once.
local n = count()
loadAs([[ TriggerServerEvent("esx:giveMoney", 1) ]], "=(load)")
expect(count() == n, "duplicate report")

print("SHIELD OK (" .. count() .. " findings)")
