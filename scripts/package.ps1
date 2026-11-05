# Windows equivalent of scripts/package.sh. Run from any folder:
#   powershell -ExecutionPolicy Bypass -File scripts\package.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$version = (Select-String -Path resource/jcks_anticheat/fxmanifest.lua -Pattern '^version "([^"]+)"').Matches[0].Groups[1].Value

Write-Host "==> Build server (Release)"
dotnet build server-src/JcksAnticheat.Server -c Release --nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw "build failed" }

if ($env:SKIP_TESTS -ne "1") {
  Write-Host "==> Tests (set JCKS_AC_SKIP_LUA=1 if lua5.4 is not installed)"
  dotnet test server-src/JcksAnticheat.Core.Tests --nologo -v quiet
  if ($LASTEXITCODE -ne 0) { throw "tests failed" }
}

Write-Host "==> Assemble dist\jcks_anticheat"
Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force dist/jcks_anticheat/server | Out-Null
foreach ($item in "fxmanifest.lua", "config.json", "settings.schema.json", "client", "shared", "shield", "html") {
  Copy-Item -Recurse "resource/jcks_anticheat/$item" "dist/jcks_anticheat/"
}
Copy-Item resource/jcks_anticheat/server/JcksAnticheat.Core.net.dll, resource/jcks_anticheat/server/JcksAnticheat.Server.net.dll dist/jcks_anticheat/server/

Compress-Archive -Path dist/jcks_anticheat -DestinationPath "dist/jcks_anticheat-$version.zip"
Write-Host "==> Done: dist\jcks_anticheat\ and dist\jcks_anticheat-$version.zip"
