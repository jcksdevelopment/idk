#!/usr/bin/env bash
# Builds the server DLLs, runs the tests, and produces a drop-in resource:
#   dist/jcks_anticheat/        -> copy into your FiveM server's resources/ folder
#   dist/jcks_anticheat-<ver>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -oP '^version "\K[^"]+' resource/jcks_anticheat/fxmanifest.lua)"

echo "==> Lua syntax check"
LUAC="$(command -v luac5.4 || command -v luac || true)"
if [ -n "$LUAC" ]; then
  find resource/jcks_anticheat -name '*.lua' -print0 | xargs -0 -n1 "$LUAC" -p
else
  echo "    luac not found, skipping"
fi

echo "==> Build server (Release)"
dotnet build server-src/JcksAnticheat.Server -c Release --nologo -v quiet

if [ "${SKIP_TESTS:-0}" != "1" ]; then
  echo "==> Tests"
  dotnet test server-src/JcksAnticheat.Core.Tests --nologo -v quiet
fi

echo "==> Assemble dist/jcks_anticheat"
rm -rf dist && mkdir -p dist/jcks_anticheat/server
cp -r resource/jcks_anticheat/{fxmanifest.lua,config.json,settings.schema.json,integrations.presets.json,client,shared,shield,html} dist/jcks_anticheat/
cp resource/jcks_anticheat/server/JcksAnticheat.Core.net.dll resource/jcks_anticheat/server/JcksAnticheat.Server.net.dll dist/jcks_anticheat/server/

echo "==> Check every file the manifest needs is packaged"
for f in settings.schema.json integrations.presets.json shield/shield.lua html/index.html html/panel.js html/panel.css server/JcksAnticheat.Core.net.dll server/JcksAnticheat.Server.net.dll; do
  [ -f "dist/jcks_anticheat/$f" ] || { echo "missing from package: $f" >&2; exit 1; }
done

if [ "${NO_OBFUSCATE:-0}" != "1" ]; then
  echo "==> Obfuscate client Lua (strip comments, randomise global names)"
  python3 scripts/obfuscate.py dist/jcks_anticheat
  if [ -n "$LUAC" ]; then find dist/jcks_anticheat -name '*.lua' -print0 | xargs -0 -n1 "$LUAC" -p; fi
  if [ "${SKIP_TESTS:-0}" != "1" ]; then
    echo "==> Heartbeat interop tests against the obfuscated build"
    JCKS_AC_RESOURCE_ROOT="$PWD/dist/jcks_anticheat" dotnet test server-src/JcksAnticheat.Core.Tests --nologo -v quiet \
      --filter "FullyQualifiedName~HeartbeatInteropTests|FullyQualifiedName~ShieldTests|FullyQualifiedName~CountermeasureTests"
  fi
fi

(cd dist && zip -qr "jcks_anticheat-${VERSION}.zip" jcks_anticheat)
echo "==> Done: dist/jcks_anticheat/ and dist/jcks_anticheat-${VERSION}.zip"
