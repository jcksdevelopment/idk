# Windows equivalent of scripts/package.sh. Run from any folder:
#   powershell -ExecutionPolicy Bypass -File scripts\package.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$version = (Select-String -Path resource/sentinel/fxmanifest.lua -Pattern '^version "([^"]+)"').Matches[0].Groups[1].Value

Write-Host "==> Build server (Release)"
dotnet build server-src/Sentinel.Server -c Release --nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw "build failed" }

if ($env:SKIP_TESTS -ne "1") {
  Write-Host "==> Tests (set SENTINEL_SKIP_LUA=1 if lua5.4 is not installed)"
  dotnet test server-src/Sentinel.Core.Tests --nologo -v quiet
  if ($LASTEXITCODE -ne 0) { throw "tests failed" }
}

Write-Host "==> Assemble dist\sentinel"
Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force dist/sentinel/server | Out-Null
foreach ($item in "fxmanifest.lua", "config.json", "client", "shared", "html") {
  Copy-Item -Recurse "resource/sentinel/$item" "dist/sentinel/"
}
Copy-Item resource/sentinel/server/Sentinel.Core.net.dll, resource/sentinel/server/Sentinel.Server.net.dll dist/sentinel/server/

Compress-Archive -Path dist/sentinel -DestinationPath "dist/sentinel-$version.zip"
Write-Host "==> Done: dist\sentinel\ and dist\sentinel-$version.zip"
