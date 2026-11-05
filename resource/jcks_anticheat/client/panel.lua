local S = JcksAC
local actionEvent

AddEventHandler("jcks_anticheat:ready", function()
  if not S.server.panelEvent then return end
  RegisterNetEvent(S.server.panelEvent, function(raw)
    local data = json.decode(raw)
    if type(data) ~= "table" then return end
    actionEvent = data.action
    SendNUIMessage({
      type = "jac_panel",
      schema = data.schema,
      config = data.config,
      result = data.result,
      message = data.message,
    })
    if not data.result then SetNuiFocus(true, true) end
  end)
end)

RegisterNUICallback("jac_panel_save", function(body, cb)
  cb({})
  if actionEvent and type(body) == "table" and type(body.config) == "string" then
    TriggerServerEvent(actionEvent, "save", body.config)
  end
end)

RegisterNUICallback("jac_panel_reload", function(_, cb)
  cb({})
  if actionEvent then TriggerServerEvent(actionEvent, "reload", "") end
end)

RegisterNUICallback("jac_panel_close", function(_, cb)
  cb({})
  SetNuiFocus(false, false)
end)
