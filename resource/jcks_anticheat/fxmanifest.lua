fx_version "cerulean"
game "gta5"
lua54 "yes"

name "jcks_anticheat"
author "JCKS"
description "JCKS Anticheat"
version "1.0.0"

shared_script "shared/crypto.lua"

client_scripts {
  "client/main.lua",
  "client/heartbeat.lua",
  "client/screenshot.lua",
  "client/panel.lua",
  "client/countermeasures.lua",
  "client/detections/*.lua",
}

server_scripts {
  "server/JcksAnticheat.Core.net.dll",
  "server/JcksAnticheat.Server.net.dll",
}

ui_page "html/index.html"

files {
  "html/index.html",
  "html/panel.js",
  "html/panel.css",
  "shield/shield.lua",
}

escrow_ignore {
  "shield/shield.lua",
}
