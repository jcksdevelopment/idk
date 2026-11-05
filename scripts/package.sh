#!/usr/bin/env bash
# Builds the server DLLs, runs the tests, and produces a drop-in resource:
#   dist/sentinel/        -> copy into your FiveM server's resources/ folder
#   dist/sentinel-<ver>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -oP '^version "\K[^"]+' resource/sentinel/fxmanifest.lua)"

echo "==> Lua syntax check"
LUAC="$(command -v luac5.4 || command -v luac || true)"
if [ -n "$LUAC" ]; then
  find resource/sentinel -name '*.lua' -print0 | xargs -0 -n1 "$LUAC" -p
else
  echo "    luac not found, skipping"
fi

echo "==> Build server (Release)"
dotnet build server-src/Sentinel.Server -c Release --nologo -v quiet

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  echo "==> Tests"
  dotnet test server-src/Sentinel.Core.Tests --nologo -v quiet
fi

echo "==> Assemble dist/sentinel"
rm -rf dist && mkdir -p dist/sentinel/server
cp -r resource/sentinel/{fxmanifest.lua,config.json,client,shared,html} dist/sentinel/
cp resource/sentinel/server/Sentinel.Core.net.dll resource/sentinel/server/Sentinel.Server.net.dll dist/sentinel/server/

if [ "${NO_OBFUSCATE:-0}" != "1" ]; then
  echo "==> Obfuscate client Lua (strip comments, randomise global names)"
  python3 scripts/obfuscate.py dist/sentinel
  if [ -n "$LUAC" ]; then find dist/sentinel -name '*.lua' -print0 | xargs -0 -n1 "$LUAC" -p; fi
  if [ "${SKIP_TESTS:-0}" != "1" ]; then
    echo "==> Heartbeat interop tests against the obfuscated build"
    SENTINEL_RESOURCE_ROOT="$PWD/dist/sentinel" dotnet test server-src/Sentinel.Core.Tests --nologo -v quiet \
      --filter "FullyQualifiedName~HeartbeatInteropTests"
  fi
fi

(cd dist && zip -qr "sentinel-${VERSION}.zip" sentinel)
echo "==> Done: dist/sentinel/ and dist/sentinel-${VERSION}.zip"
