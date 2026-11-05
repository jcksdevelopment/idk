local root = arg[1]
local reports = {}
local started = { testres = true, jcks_anticheat = true, ox_lib = true }
local threads = {}

function GetCurrentResourceName() return "testres" end
function GetResourceMetadata(r, k) if r == "testres" and k == "jac_antidump" then return "yes" end end
function NetworkIsSessionStarted() return true end
local netHandlers, serverEvents = {}, {}
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
json = { decode = function(s) return load("return " .. s)() end }
function PlayerPedId() return 42 end
function PlayerId() return 0 end
function GetVehiclePedIsIn() return 0 end
local clock = 0
function GetGameTimer() clock = clock + 2000 return clock end
local uses = {}
function GetResourceState(r) return started[r] and "started" or "missing" end
function TriggerEvent(name, res, kind, detail)
  if name ~= "jcks_anticheat:shield" or kind == "hello" then return end
  if kind == "use" then uses[#uses + 1] = res .. "|" .. detail.src return end
  reports[#reports + 1] = kind .. "|" .. detail.fn
end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
local calls = 0
function TriggerServerEvent(name) calls = calls + 1 serverEvents[#serverEvents + 1] = name end
function SetEntityHealth() calls = calls + 1 end
function CreateVehicle() calls = calls + 1 return 7 end
function SetEntityCoords() calls = calls + 1 end
Citizen = { InvokeNative = function() calls = calls + 1 end }

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

loadAs([[ function Helper(cb) cb() end
          function Helper2() TriggerServerEvent("bank:deposit", 5) end
          TriggerServerEvent("legit:event") CreateVehicle(1) ]], "@@testres/client/main.lua")
loadAs([[ SetEntityCoords(1, 0, 0, 0) Citizen.InvokeNative(0x1234) ]], "@@ox_lib/imports/teleport/client.lua")
expect(count() == 0, "legit code reported: " .. table.concat(reports, ","))
expect(calls >= 4, "wrappers must still call the originals (calls=" .. calls .. ")")

expect(netHandlers["jcks_anticheat:ad:testres"] ~= nil, "anti-dump handler not registered")
coroutine.resume(threads[#threads])
table.remove(threads)
local asked = false
for _, e in ipairs(serverEvents) do if e == "jcks_anticheat:ad" then asked = true end end
expect(asked, "anti-dump request not sent")
local ran = false
_G.__adProbe = function() ran = true end
_G.__adHandler = netHandlers["jcks_anticheat:ad:testres"]
local before = count()
loadAs([==[ __adHandler([[{ { n = "client/main.lua", c = "__adProbe() TriggerServerEvent('legit:fromStreamedFile')" } }]]) ]==], "@citizen:/scripting/lua/scheduler.lua")
expect(ran, "streamed file did not run")
expect(count() == before, "streamed file's calls were reported as injection: " .. table.concat(reports, ",", before + 1))

loadAs([[ SetEntityHealth(42, 200) SetEntityHealth(77, 200) ]], "@@testres/client/hospital.lua")
expect(#uses == 1 and uses[1] == "testres|heal", "use reporting: " .. table.concat(uses, ","))
expect(count() == 0, "legit heal reported as injection")

loadAs([[ TriggerServerEvent("esx:giveMoney", 999999) ]], "=(load)")
expect(reports[1] == "call|TriggerServerEvent", "plain injected call not reported")

loadAs([[ CreateVehicle(2) ]], "@@totally_legit_menu/main.lua")
expect(reports[2] == "call|CreateVehicle", "fake resource chunk not reported")

loadAs([[ Helper(function() SetEntityCoords(1, 9, 9, 9) end) ]], "menu")
expect(reports[3] == "call|SetEntityCoords", "injected callback via legit helper not reported")
loadAs([[ Helper2() ]], "menu2")
expect(#reports == 4 and reports[4]:find("TriggerServerEvent"), "injected frame deeper in the stack not reported")

resumeAll()
resumeAll()
local before = count()
loadAs([[ function OpenModMenu() end ]], "=(executor)")
_G.CreateVehicle = function() end
resumeAll()
local kinds = table.concat(reports, ",", before + 1)
expect(kinds:find("global|OpenModMenu"), "injected global function not reported: " .. kinds)
expect(kinds:find("tamper|CreateVehicle"), "wrapper replacement not reported: " .. kinds)

local n = count()
loadAs([[ TriggerServerEvent("esx:giveMoney", 1) ]], "=(load)")
expect(count() == n, "duplicate report")

print("SHIELD OK (" .. count() .. " findings)")
