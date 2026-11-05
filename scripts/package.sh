#!/usr/bin/env bash
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

echo "==> Check every file the manifest references is packaged"
python3 - "dist/jcks_anticheat" <<'PY'
import glob, os, re, sys
root = sys.argv[1]
manifest = open(os.path.join(root, "fxmanifest.lua")).read()
missing = []
for ref in re.findall(r'"([^"@]+\.(?:lua|dll|html|js|css|json))"', manifest):
    if not glob.glob(os.path.join(root, ref)):
        missing.append(ref)
for extra in ("config.json", "settings.schema.json", "integrations.presets.json"):
    if not os.path.exists(os.path.join(root, extra)):
        missing.append(extra)
if missing:
    print("missing from package: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
PY

if [ "${OBFUSCATE_DLL:-0}" = "1" ]; then
  echo "==> Obfuscate server DLLs (Obfuscar)"
  OBF="$(command -v obfuscar.console || echo "$HOME/.dotnet/tools/obfuscar.console")"
  TMP="$(mktemp -d)"
  cat > "$TMP/obfuscar.xml" <<XML
<?xml version="1.0"?>
<Obfuscator>
  <Var name="InPath" value="$PWD/dist/jcks_anticheat/server" />
  <Var name="OutPath" value="$TMP/out" />
  <Var name="KeepPublicApi" value="true" />
  <Var name="HidePrivateApi" value="true" />
  <Var name="HideStrings" value="true" />
  <Var name="RenameProperties" value="true" />
  <Var name="RenameEvents" value="true" />
  <Var name="RenameFields" value="true" />
  <AssemblySearchPath path="$HOME/.nuget/packages/citizenfx.core.server/1.0.26803/lib/netstandard20" />
  <Module file="\$(InPath)/JcksAnticheat.Core.net.dll" />
  <Module file="\$(InPath)/JcksAnticheat.Server.net.dll" />
</Obfuscator>
XML
  "$OBF" "$TMP/obfuscar.xml" > "$TMP/log.txt"
  cp "$TMP/out/JcksAnticheat.Core.net.dll" "$TMP/out/JcksAnticheat.Server.net.dll" dist/jcks_anticheat/server/
  rm -rf "$TMP"
fi

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
