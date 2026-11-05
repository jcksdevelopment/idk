local S = JcksAC

local CHUNK = 24 * 1024
local BPS = 64 * 1024

AddEventHandler("jcks_anticheat:ready", function()
  local reqEvent, upEvent = S.server.ssRequest, S.server.ssUpload
  if not reqEvent or not upEvent then return end

  RegisterNetEvent(reqEvent, function(captureId)
    if type(captureId) ~= "string" then return end
    if GetResourceState("screenshot-basic") ~= "started" then
      TriggerLatentServerEvent(upEvent, BPS, captureId, 0, 0, "unavailable")
      return
    end
    exports["screenshot-basic"]:requestScreenshot({ encoding = "jpg", quality = 0.6 }, function(dataUri)
      local b64 = dataUri:gsub("^data:image/%w+;base64,", "")
      local total = math.ceil(#b64 / CHUNK)
      for i = 1, total do
        local part = b64:sub((i - 1) * CHUNK + 1, i * CHUNK)
        TriggerLatentServerEvent(upEvent, BPS, captureId, i, total, part)
      end
    end)
  end)
end)
