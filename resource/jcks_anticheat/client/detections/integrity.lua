-- Integrity detections: resource count/list spoofing, injected resources, injected command handlers,
-- tampered natives in our own environment, and the NUI devtools / frame-injection sensor.

local S = JcksAC

-- Capture native references at load time. An executor that later swaps these globals (a common
-- way to blind scanners) is caught by comparing identities.
local canaries = {
  GetNumResources = GetNumResources,
  GetResourceByFindIndex = GetResourceByFindIndex,
  GetEntityHealth = GetEntityHealth,
  GetPlayerInvincible = GetPlayerInvincible,
  GetEntityCoords = GetEntityCoords,
  TriggerServerEvent = TriggerServerEvent,
  GetRegisteredCommands = GetRegisteredCommands,
}

local function listResources()
  local out, count = {}, GetNumResources()
  for i = 0, count - 1 do
    local name = GetResourceByFindIndex(i)
    if name then out[#out + 1] = name end
  end
  return out, count
end

S.register("integrity.resources", 15000, function()
  local names, count = listResources()

  -- Executors sometimes hook GetNumResources to hide themselves; the iteration and the count disagree.
  local iterated = 0
  for i = 0, count + 8 do
    if GetResourceByFindIndex(i) then iterated = iterated + 1 end
  end
  if iterated ~= count then
    S.flag("EXE_RESOURCE_COUNT", { n = count, it = iterated })
  end

  -- Anything started on the client that the server never started.
  local known = {}
  for _, r in ipairs(S.server.resources) do known[r] = true end
  if next(known) then
    for _, name in ipairs(names) do
      if not known[name] and GetResourceState(name) == "started" then
        S.flag("EXE_RESOURCE_INJECT", { r = name:sub(1, 48) })
      end
    end
  end
end)

local function isKnownResource(name)
  for _, r in ipairs(S.server.resources) do
    if r == name then return true end
  end
  return false
end

AddEventHandler("onClientResourceStart", function(name)
  if not S.ready or isKnownResource(name) then return end
  -- A resource the server just started reaches us before (or after) the server's notice of it;
  -- give that notice time to arrive before calling it an injection.
  CreateThread(function()
    Wait(8000)
    if not isKnownResource(name) and GetResourceState(name) == "started" then
      S.flag("EXE_RESOURCE_INJECT", { r = name:sub(1, 48), live = true })
    end
  end)
end)

-- Every registered command records the resource that registered it. Built-in console commands
-- have no resource. A command owned by a resource the server never started was injected.
S.register("integrity.commands", 20000, function()
  local known = {}
  for _, r in ipairs(S.server.resources) do known[r] = true end
  if not next(known) then return end
  for _, cmd in ipairs(GetRegisteredCommands()) do
    local owner = cmd.resource
    if owner and owner ~= "" and owner ~= "internal" and not known[owner] then
      S.flag("EXE_COMMAND_INJECT", { c = tostring(cmd.name):sub(1, 48), r = tostring(owner):sub(1, 48) })
    end
  end
end)

S.register("integrity.canary", 10000, function()
  local env = _ENV
  for name, fn in pairs(canaries) do
    if env[name] ~= fn then
      S.flag("EXE_GLOBAL_TAMPER", { g = name })
    end
  end
end)

-- NUI sensor. html/index.html posts here; the page itself is invisible and takes no focus.
RegisterNUICallback("jac_sensor", function(data, cb)
  cb({})
  if type(data) ~= "table" then return end
  if data.kind == "devtools" then
    S.flag("NUI_DEVTOOLS", { how = tostring(data.how):sub(1, 32) })
  elseif data.kind == "frame" then
    S.flag("NUI_FRAME_INJECT", { tag = tostring(data.tag):sub(1, 16), src = tostring(data.src):sub(1, 96) })
  end
end)
