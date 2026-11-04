fx_version "cerulean"
game "gta5"
lua54 "yes"

name "sentinel"
description "Sentinel anticheat: Lua client scanner + C# server authority"
version "1.0.0"

shared_script "shared/crypto.lua"

client_scripts {
  "client/main.lua",
  "client/heartbeat.lua",
  "client/screenshot.lua",
  "client/detections/*.lua",
}

-- Built from server-src/Sentinel.Server (see README). The build copies the DLLs here.
server_scripts {
  "server/Sentinel.Core.net.dll",
  "server/Sentinel.Server.net.dll",
}

ui_page "html/index.html"
files { "html/index.html" }

-- config.json is read by the server with LoadResourceFile; it is not sent to clients.

-- screenshot-basic is optional; only the AI vision capture uses it.
