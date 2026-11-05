# JCKS Anticheat

An anticheat for FiveM servers, with a moderation dashboard.

| Part | Path | Stack |
|---|---|---|
| Client scanner | `resource/jcks_anticheat/client`, `shared`, `html` | Lua 5.4, NUI |
| Server authority | `server-src/JcksAnticheat.Server` → `resource/jcks_anticheat/server` | C#, built with the .NET 10 SDK, targets `netstandard2.0` |
| Detection core, AI vision | `server-src/JcksAnticheat.Core` | C#, no FiveM dependency, unit-tested |
| Dashboard | `dashboard` | Next.js 16 (App Router), React 19, Tailwind CSS 4 |
| Threat matrix | `docs/THREAT_MATRIX.md` | Each cheat capability mapped to the code that detects it |

## How it works

```
 game client (Lua)                      game server (C#)                         dashboard (Next.js)
 ─────────────────                      ────────────────                         ───────────────────
 detection modules ──flags──┐
                            ▼
 heartbeat.lua  ── encrypted, MAC'd, ──▶ HeartbeatManager ── violations ──┐
   every 5 s       ratcheting packet     (verify, decrypt)                │
                                                                          ▼
                       OneSync events ─▶ Movement / Damage / Explosion ─▶ ViolationLedger ─▶ log / screenshot /
                       + 1 Hz state      Entity / PlayerState validators   (decaying score)   kick / ban
                                                                          │
 screenshot-basic ── chunked JPEG ─────▶ ScreenshotAssembler ─▶ AIVisionEvaluator ─▶ Vision Vault (human review)
                                                                          │
                                         DashboardBridge ── HTTPS push ──▶ /api/ingest ──▶ live log, players, bans
                                                         ◀── poll ────────  /api/server/commands (ban/kick/capture)
```

**Scores survive reconnects.** When a player leaves, their score is kept under their license
identifier and restored when they rejoin, still decaying while they're away. A cheater who gets
kicked and reconnects keeps climbing toward the ban threshold instead of starting from zero.

**The server decides; the client only reports.** Code on the cheater's machine can be patched, so
client flags add to a suspicion score but can never ban on their own. A ban needs a server-observed
signal: an impossible movement, an invalid weapon hit, a forbidden game event, or a failed or missing
heartbeat. `ViolationLedger` enforces this in code (see the `ClientOnlyEvidenceNeverBans` test).

**No "ban me" event.** Client detections travel inside the heartbeat as encrypted flags. There is no
plain net event a cheat could block or spoof to stay clean. Blocking the heartbeat entirely trips
`HB_MISSING`.

### The heartbeat

1. The client fires `jcks_anticheat:hello`. The server answers on `jcks_anticheat:init` with a random 32-byte
   session key, a challenge, and four event names randomised per server boot.
2. Every 5 s the client sends `seq, nonce, ciphertext, mac`, where:
   - `ciphertext` = SHA-256-CTR(key, nonce, `{seq, challenge, flags, state}`)
   - `mac` = HMAC-SHA256(key, `seq ‖ nonce ‖ ciphertext`)
3. The server checks sequence, MAC and challenge, then replies with the next challenge. Both sides
   ratchet `key = SHA256(key ‖ mac)`, so a captured packet can't be replayed and a forger who missed
   one packet loses the key.
4. A second handshake after a working session is itself a violation (`HB_INVALID`).
5. A client that never handshakes can't opt out: once the player has a ped in the world, they
   have `handshakeTimeoutSeconds` (120) to send `jcks_anticheat:hello`, or they get `HB_MISSING`. The
   server's own movement and health checks run from the moment the ped exists, handshake or not.
6. An invalid heartbeat (`HB_INVALID`) or 20 s of silence (`HB_MISSING`) disconnects the player
   immediately (`scoring.dropImmediately`). That's a kick, not a ban: a crashed or frozen client
   looks the same as a killed scanner.

The crypto is pure Lua 5.4 (`shared/crypto.lua`) and is byte-compatible with the C# side. The test
suite runs the real `crypto.lua`, `main.lua` and `heartbeat.lua` under `lua5.4` with stubbed natives
and verifies the packets with the C# `HeartbeatManager`.

**Limits.** The session key crosses the network once, inside a FiveM event. Anyone who can read the
game client's memory can lift the key and reimplement the protocol. The heartbeat raises the cost
of killing or faking the scanner; it doesn't make that impossible. That's why bans rest on
server-side evidence.

### Shield: catching Lua executors inside every resource

Lua executors inject menu code into a running resource's Lua state, so a scanner living only in
its own resource never sees it. The shield (`shield/shield.lua`) goes inside every resource
instead:

```
jac shield install      (server console; adds the include to every resource with client code)
refresh
```

Then restart those resources (or the server). Each manifest gets one first line,
`client_script "@jcks_anticheat/shield/shield.lua"`, and the original is saved next to it as
`fxmanifest.lua.jac-backup`. `jac shield uninstall` removes the line and `jac shield status`
counts installs.

How it detects:
- FiveM names every chunk loaded from a resource file `@@<resource>/<path>`. Code an executor
  pushes in has no file behind it (`=(load)`, raw code text, or a made-up resource name).
- The shield wraps what menus call: server events, `ExecuteCommand`, vehicle/ped/object spawning,
  weapon and ammo natives, teleport, godmode/proofs/visibility, health and armour, explosions,
  vehicle repair/boost/handling, resurrect, spectate, attach, and `Citizen.InvokeNative`. On
  each call it walks the stack, and any frame from a non-file chunk means injected code is behind
  the call (`EXE_LUA_INJECT`). That holds even when the menu calls through the resource's own
  helper functions.
- Every 10 s it flags new global functions defined by non-file chunks (menu frameworks define
  their UI and option tables globally), and wrappers swapped back to the original natives
  (`EXE_SHIELD_TAMPER`).
- These are client signals. They add to the score and can kick, but never ban on their own.

**Limits.** An executor that names its chunk after a running resource (`@@qb-core/x.lua`) passes
the chunk-name check. The shield doesn't verify that the file exists, because escrowed resources
can't be read back. Native C++ menus that never touch Lua aren't visible to it; for those you rely
on the server-side checks, the heartbeat and AI vision.

### Server-side checks

| Validator | Catches |
|---|---|
| `MovementValidator` | Teleport, speedhack (on foot and in vehicles), noclip rising faster than gravity allows. Uses OneSync positions, not client claims. Falling is always allowed. |
| `DamageValidator` | Damage multipliers, out-of-range hits, silent aim (shooter facing away from the victim), bullet trajectory (reported impact direction vs. the shooter→victim line), rapid fire, headshot ratio over 25 hits |
| `AbsorbTracker` | Semi-godmode: confirmed hits that never lower the victim's health |
| `ExplosionValidator` | Explosive ammo (`EXP_TAG_BULLET`), blacklisted and stealth explosions, explosion spam. Cancels the event. |
| `EntityValidator` | Blacklisted vehicles and objects, spawn floods. Cancels `entityCreating`. |
| `VehicleOwnership` | Remembers who spawned each vehicle; another player in the driver seat of it while it's locked is a hijack (`VEH_HIJACK`). Lockpick/key scripts unlock first; garages and jobs can grant `vehicle` grace. |
| `GameEventValidator` | `startProjectileEvent` (projectiles spawned away from the shooter or as another player, blacklisted launchers, spam), `fireEvent` (fires on other players, spam), `ptFxEvent` (particle spam, oversized or attached to other players). Offending events are cancelled. |
| `StateConsistencyValidator` | Hooked natives and forged heartbeats: the health, armour and position the client reports must match the server's own view (3 heartbeats in a row before reporting) |
| `PlayerStateValidator` | Health and armour jumps without a server-granted heal, max-health tampering |
| `PlayerFlagsValidator` | Values the server reads straight from the player's OneSync state: super-jump flag (`IsPlayerUsingSuperJump`), weapon and melee damage modifiers, weapon defense modifiers, max health, and collision turned off on foot for `server.collisionStreakSeconds`. The client can't hide these from the server; when one fires, the server also tells the client to undo it. |
| `AttachmentWatch` | Props, cages or vehicles created by one player and attached to other players' peds (`ENT_ATTACH_PLAYER`, above `entities.maxAttachedToOthers`); they are deleted. Peds attached to peds (carry/escort) are not counted. |
| Game events | `giveWeaponEvent` / `removeWeaponEvent` / `removeAllWeaponsEvent` (always cancelled), `clearPedTasksEvent` and `givePedScriptedTaskEvent` against other players (cancelled) |
| Honeypots | Decoy net events no real resource fires (`honeypotEvents` in config) |
| Protected events | `protectedEvents` (event = max per minute) rate-limits sensitive server events of other resources (payouts, transfers, item grants) per player; over the limit they're reported (`NET_EVENT_SPAM`) and cancelled. Editable live in the panel and dashboard. |
| Names & chat | Connections whose name contains HTML/script (chat/NUI injection) or an operator-blocked word are refused; chat messages sent under another player's name are cancelled (`NET_CHAT_SPOOF`). |
| `RateLimiter` | Per-player token bucket, shared by JCKS Anticheat's own events and other resources through `exports.jcks_anticheat:Guard`. A sustained flood (40 denied events in 10 s) disconnects the player. |

**Idle cost.** Everything is event-driven except one coroutine that wakes once a second and returns
immediately when nobody is online. Buckets refill lazily and nothing allocates at idle. I designed
it for 0.00 ms idle in resmon, but I haven't measured it on a live server.

### AI vision

When a player's score crosses `scoring.screenshotAt`, every minute while it stays above that line
(limited by `vision.cooldownSeconds`), or when a moderator clicks **Capture**, the server asks the
client for a frame. The frame arrives as base64 chunks over a latent event. The server
only accepts chunks for capture IDs it issued itself. It saves the frame to
`resource/jcks_anticheat/data/vision/` and sends it to the vision model:

- **`anthropic`** (default): the Claude Messages API over raw HTTP, model `claude-opus-5-5`. The
  official C# SDK targets modern .NET and can't load inside FiveM's Mono runtime, so the request is
  built by hand. The response format is constrained to a JSON schema with `output_config.format`.
  `fallbacks: "default"` is enabled, so a refusal from a safety classifier is retried on a fallback
  model. A refusal that still happens becomes an `error` verdict, never a ban.
- **`openai-compatible`**: DeepSeek or any OpenAI-style endpoint that accepts `image_url` parts.

The prompt lists what counts as a cheat overlay (ESP boxes, snap lines, name/distance text, FOV
circles, mod-menu windows) and what doesn't (normal HUD, phones, inventories, server nametags).
**Verdicts only go to the Vision Vault for human review.** `VIS_AI_FLAG` carries severity 0, so a
verdict never pushes anyone toward a kick or ban. Overlays drawn by an external program on a
transparent window don't appear in a game screenshot.

The API key is read from the environment variable named in `vision.apiKeyEnv` (default
`JCKS_AC_VISION_API_KEY`), never from `config.json`.

## Install on a FiveM server

Requirements: OneSync enabled. `screenshot-basic` is optional and only needed for AI vision; it's
the one external dependency.

1. Build the ready-to-install package (needs the .NET SDK 8 or newer; the repo uses 10):
   ```bash
   ./scripts/package.sh
   ```
   On Windows: `powershell -ExecutionPolicy Bypass -File scripts\package.ps1`. This checks the Lua,
   builds the DLLs, runs the tests, and writes `dist/jcks_anticheat/` plus `dist/jcks_anticheat-<version>.zip`.
   `package.sh` also hardens the shipped client Lua (`scripts/obfuscate.py`): it strips comments and
   renames the scanner's global tables to random names chosen per build, so an executor can't find
   them by a known name. It then reruns the heartbeat interop tests against that obfuscated build.
   This is light obfuscation, not protection; `NO_OBFUSCATE=1` turns it off. The Windows script
   doesn't obfuscate.
   CI (`.github/workflows/build.yml`) does the same on every push and uploads `dist/jcks_anticheat/`
   as the `jcks_anticheat-resource` artifact.
2. Copy `dist/jcks_anticheat` into your server's `resources/` folder.
3. Add to `server.cfg`, after your framework:
   ```
   ensure jcks_anticheat
   add_ace group.admin jcks_anticheat.bypass allow
   add_ace group.admin jcks_anticheat.admin allow
   ```
   Then from the server console run `jac shield install`, then `refresh`, and restart the server
   so the shield loads into every resource (see "Shield" above).
4. Leave `"dryRun": true` in `config.json` for the first sessions. Every detection is logged and
   sent to the dashboard, but nobody is kicked or banned. Tune thresholds against what you see,
   then set it to `false`.

### Integrating with your scripts

JCKS Anticheat flags legitimate jumps (hospital heals, admin noclip, apartment teleports) unless you tell
it about them. Grant grace from the **server**:

```lua
-- after your hospital script heals a player
exports.jcks_anticheat:GrantGrace(source, "heal", 5000)
-- before an admin teleport / noclip / godmode
exports.jcks_anticheat:GrantGrace(source, "teleport", 10000)
exports.jcks_anticheat:GrantGrace(source, "noclip", 600000)
```

If your server legitimately does something a check looks for (tuning scripts calling
`SetVehicleHandlingFloat`, infinite stamina, custom vision modes), add the code to
`scoring.ignore`, for example `"ignore": ["VEH_HANDLING", "PLY_STAMINA"]`.

Per-detection exemptions use the same ACE with the code appended:
`add_ace group.police jcks_anticheat.bypass.WPN_GIVE_ALL allow` exempts police from that one
detection and its countermeasure only. `scoring.alwaysBan` lists codes that ban on the first
detection. It's an explicit opt-in, so it also applies to client-side codes.

Kinds: `heal`, `armor`, `teleport`, `noclip`, `godmode`, `invisible`, `vision`, `ragdoll`, `superjump`, `camera`,
`vehicle`. Server grace also reaches the client scanner. A client-side `exports.jcks_anticheat:GrantGrace`
exists for client-only scripts, but the server ignores it.

Other exports: `Guard(source, bucket)` rate-limits your own net events (it returns `false` when the
player is over budget), `GetScore(source)`, and `BanPlayer(source, reason)`.

### Live settings (no restart)

Settings can be changed while the server runs, from three places. All three validate the new
settings first; a rejected change leaves everything as it was.

| Where | How | Who |
|---|---|---|
| In game | `/jac panel` opens the settings panel; **Save & apply** writes `config.json` and applies it | ACE `jcks_anticheat.admin` |
| Web dashboard | **Settings** page; the game server validates, saves, applies and confirms back | Head Admin |
| By hand | Edit `config.json`, then `/jac reload` (console or in game), or **Reload from file** in the panel or dashboard | console / admin ACE |

Applying a change takes effect at once: thresholds and limits, blacklists, honeypot events, and
the client scanner's settings (pushed to every connected player). Changing
`dashboard.secretEnv` needs a restart, because the secret is read from the environment at start.

Console and admin commands:

```
jac status | reload | panel | dryrun on|off | shield install|uninstall|status
```

```
add_ace group.admin jcks_anticheat.admin allow
```

The panel and dashboard are generated from `settings.schema.json`, so a new setting needs one
entry there to appear in both.

### Configuration

Everything lives in `resource/jcks_anticheat/config.json`. The thresholds of every client check
(freecam distance, super jump height, on-foot speed, aim snap angle, triggerbot reaction time,
health jump, noclip float height, rainbow paint, and so on) are under `client` and in the
"Client checks" section of the panel and dashboard. Server-side tolerances (client-vs-server
state comparison, damage absorption, health/armour jumps) are under `server` ("Server checks"). The file also holds: scoring thresholds and half-life, per-code
severity overrides, `ignore` codes (switched off entirely; the client stops sending them), `logOnly` codes, movement and damage limits, explosion and entity rules,
weapon/vehicle/object blacklists, honeypot event names, and vision and dashboard settings. Codes
and default severities are listed in `docs/THREAT_MATRIX.md`.

### Countermeasures: the cheat never works, whatever the punishment

Punishment (log, screenshot, kick, ban) is decided by the score. Separately, every detection
undoes its effect at once, even in dry run and even when the code is set to log only:

| Effect | Undone by |
|---|---|
| Spawned vehicles/objects/peds, explosions, projectiles, fires, particles, weapon give/remove, invalid damage, spoofed chat, protected-event spam | the event is cancelled on the server |
| Teleport, speedhack, noclip rising | server puts the player (or their vehicle) back at the last valid position |
| "Bring all players" | every victim is put back where they were |
| Hijacked vehicle | the player is pulled out of the driver seat |
| Godmode, proofs, invisibility, tiny ped, spectate, no-ragdoll, night/thermal vision | switched off |
| Health or armour regen, unauthorised revive | health/armour restored, the revived player dies again (needs the shield, so trusted heals aren't undone) |
| Damage modifier, infinite ammo, "give all weapons" | modifiers reset, infinite ammo off, weapons removed |
| Vehicle godmode, power boost, handling edit, instant repair, plate change | reset to the values before the change |
| Freecam, noclip collision/floating | camera returned, collision on, player put back on the ground |

Turn it off with `countermeasures.enabled`, or per code with `countermeasures.skip`. Players with
the bypass ACE are left alone.

### Resource integrations

Every server runs different scripts that legitimately heal, teleport or spawn things. Instead of
editing those scripts, tell the anticheat which resource may do what:

```
integrations.resources:   qb-ambulancejob=heal,armor,teleport
                          my_admin_menu=*
```

The shield, running inside every resource, sees which resource calls e.g. `SetEntityHealth` on
the local player. That report goes out with an immediate heartbeat. Server-side movement and
health verdicts wait 2.5 s for it, so a legitimate teleport or heal is never punished or put back
just because the report arrived a moment after the position or health changed. When that resource is trusted for `heal`, the matching detections pause for
`integrations.graceMs` on the client, and the server grants the same grace after checking the
rule itself (rate-limited).

- Behaviours: `heal armor godmode teleport invisible noclip spectate vehicle weapons camera ragdoll vision superjump *`.
- `integrations.presets.json` ships starting rules for popular resources: txAdmin (`monitor`),
  vMenu, EasyAdmin, qb-/ps- admin menus, qb-core, es_extended, ambulance and police jobs, prisons,
  multicharacter and spawn, apartments and housing, appearance and clothing, vehicle shops,
  garages, mechanics and customs, inventories, phones. They apply only to resources you run, and
  your own rules override them. They're best-effort; check them against your versions.
- Learning mode (`integrations.learning`) records what each resource does. `jac integrations
  suggest` lists what's not trusted yet and `jac integrations apply` saves it.

### Anti-dump

Cheaters copy other servers' client scripts out of the game cache. For resources you protect,
the client scripts are never downloaded. The anticheat streams them after the heartbeat
handshake, once per session, and the shield runs them under their real file names.

```
jac antidump protect my_resource      moves its client .lua files out of the manifest (backup kept)
refresh
ensure my_resource
jac antidump unprotect my_resource    restores the original manifest
jac antidump status
```

Requirements and limits: the resource needs the shield (`protect` adds it). The scripts start a
moment later than usual, after the network handshake. A tool that hooks `load()` in memory can
still capture the code. Anti-dump stops cache copying, not memory dumping. Escrow remains the
stronger option for code you sell.

### Backdoor scanner

On every server start (`backdoorScanner.scanOnStart`) and on `jac scan`, every resource's `.lua`,
`.js` and `.cs` files are scanned for what backdoors need to do, not for named panels:
downloaded code executed with `load`/`eval`, shell commands, reading secret convars
(`rcon_password`, `sv_licenseKey`, ...), granting ACE permissions from code, writing into other
resources' manifests, reading `server.cfg`, long encoded byte payloads, `load(string.char(...))`,
javascript-obfuscator output and packed single-line Lua. Escrowed (encrypted) files are skipped.

Findings go to the console with an id, file and line:

```
[HIGH] 3f9a1c0e  some_resource/server/main.lua:42  LUA_REMOTE_LOAD: Code downloaded over HTTP is executed with load()
    > load(body)()
```

Nothing is changed until you choose to:

```
jac scan                      rescan
jac scan list                 show the last results again
jac scan remove <id>          delete the flagged line (backup: <file>.jac-bak)
jac scan quarantine <id>      move the file to <resource>/.jac-quarantine/
jac scan ignore <id>          mark as reviewed (saved in backdoorScanner.ignoreIds)
```

The dashboard's **Backdoors** page shows the last scan. Head Admins can rescan, remove a line,
quarantine a file or ignore a finding from there, with a confirmation step; the game server does
the work.

`backdoorScanner.autoAction` (`none` / `remove` / `quarantine`) applies an action automatically
from `autoActionMinSeverity`. The default is `none`. Against `cfx-server-data`, `qb-core`,
`es_extended`, `ox_lib`, `ox_inventory` and `oxmysql` (662 files) it reports only the stock
`runcode` resource, which really does execute arbitrary code behind the rcon password.

### server.cfg audit

On start (`auditOnStart`) and on `jac audit`, the server's own security convars are compared with
the FiveM documentation: `onesync`, `sv_scriptHookAllowed`, `sv_enableNetworkedPhoneExplosions`,
`sv_filterRequestControl`, `sv_enableNetworkedSounds`, `sv_enableNetworkedScriptEntityStates`,
`sv_entityLockdown`, `sv_pureLevel` and `sv_stateBagStrictMode`. Each suggestion is printed with
the `set` line to add and why; nothing is changed automatically. Some (`sv_entityLockdown relaxed`,
`sv_stateBagStrictMode true`) break scripts that create entities or write state bags from the
client, so they are listed as low/info.

### Discord logs

Set `discord.enabled` and give the FiveM process the webhook URL in the variable named by
`discord.webhookEnv` (default `JCKS_AC_DISCORD_WEBHOOK`). Detections at or above
`discord.minAction` (default `kick`) are posted as embeds with player, action, score and evidence.
Bans and settings changes are always posted. Embeds are batched (10 per message) and sent off the
game thread.

## Licensing (selling the anticheat)

**What Cfx Asset Escrow does and doesn't do.** Escrow (Keymaster/Tebex) encrypts the resource's
`.lua` files and lets it run only on servers whose license key belongs to the buyer's Cfx account.
Every server of that account can run it, so escrow alone doesn't mean one server. It also leaves
`.dll` files unencrypted, and the server half of this anticheat is a .NET DLL.

**The built-in license lock** adds "one key = one server" on top:

1. On your machine (once): `cd license-server && npm run keygen`. Keep
   `data/license.key.pem` secret and backed up.
2. Copy `data/license.pub.pem` to `server-src/JcksAnticheat.Server/license.pub.pem`, and put your
   license server's URL in `server-src/JcksAnticheat.Server/license.url`. Build. Both are compiled
   into the DLL (and git-ignored). A build without `license.pub.pem` is a development build with
   no license check.
3. Run the license server (`JAC_LICENSE_ADMIN_TOKEN=... npm start`, behind HTTPS; set
   `JAC_TRUST_PROXY=1` behind a reverse proxy). Create a key per sale:
   ```bash
   curl -X POST -H "Authorization: Bearer $JAC_LICENSE_ADMIN_TOKEN" -H "content-type: application/json" -d '{"owner":"Customer RP"}' https://your-license-host/v1/admin/licenses
   ```
   Also available: `GET /v1/admin/licenses`, `POST /v1/admin/reset {id}` (move a license, limited
   by `maxResets`) and `POST /v1/admin/revoke {id}`.
4. The buyer adds `set jcks_ac_license "JAC-XXXXX-XXXXX-XXXXX-XXXXX"` to `server.cfg`.

On start the resource activates the key. The first activation binds it to that server's public IP
plus an install fingerprint (project name, install path, endpoint). Any other server using the
same key is refused, however many times the resource is downloaded. Responses are RSA-signed and
checked against the public key inside the DLL, so a fake license server doesn't work. The license
is rechecked every 6 hours. If the license server is down, the last activation keeps working for
72 hours. Without a valid license nothing runs: no handshake, no checks, no punishments.

**Limits.** A .NET DLL can be decompiled and patched, so this is a strong barrier, not an
unbreakable one. Build sale packages with `OBFUSCATE_DLL=1 ./scripts/package.sh`. This runs
Obfuscar over both server DLLs: private names are scrambled and string literals (event names, the
license URL) are encrypted, while the public API that FiveM loads stays intact. Install it once
with `dotnet tool install --global Obfuscar.GlobalTool`. The obfuscated DLLs were checked to
parse, validate and round-trip the config and to run the backdoor scanner. Ship escrow for the Lua
part, and keep the license server's private key off the build machine. Tebex can sell the keys: create a key in your Tebex delivery step through the
admin API.

## Dashboard

```bash
cd dashboard
```
```bash
npm install
```
```bash
cp .env.example .env.local
```
```bash
npm run build && npm start
```

Sign in with **Continue with Discord**. The login is a mock OAuth2 authorization-code flow (state
cookie, consent screen, code exchange, HMAC-signed session cookie) that never contacts Discord. To
use real Discord, replace `exchangeCode` in `src/lib/auth.ts` with a token exchange and a
`/users/@me` plus guild-role lookup.

- **Live**: terminal-style stream of detections, bans, vision verdicts and staff actions over
  Server-Sent Events, with pause, filter and level controls.
- **Players**: search by name, ID or identifier, with pagination, live scores, heartbeat health,
  and per-player detection history. Capture, kick and ban actions.
- **Bans**: search, pagination, expiry state, and unban.
- **Vision Vault**: captures awaiting review, the model's verdict and findings, and dismiss,
  confirm, or confirm-and-ban.

Support-role accounts can kick and capture; bans and unbans need Moderator or above.

**Connecting the game server.** In `config.json` set `dashboard.enabled: true` and `dashboard.url`.
Then give the FiveM process the same secret as the dashboard:

```bash
export JCKS_AC_DASHBOARD_SECRET="$(openssl rand -hex 32)"
```

The game server pushes event batches to `POST /api/ingest` and polls `GET /api/server/commands`.
Every connection is outbound, so the game server needs no open port. A ban issued for a player
who has already left uses the identifiers the dashboard last saw.

**Demo mode** (`JCKS_AC_DEMO=1`, the default) seeds sample players, bans and captures, and
streams a fake detection every few seconds, so you can try the UI without a game server. When no
game server is connected it also simulates the server's response to staff actions. Set
`JCKS_AC_DEMO=0` in production.

The store is a single process, persisted to `dashboard/.data/` (state JSON plus capture images).
It keeps at most `JCKS_AC_MAX_CAPTURES` (1000) captures, deleting dismissed and clean ones before
pending ones and confirmed evidence last. The game server keeps the newest `vision.maxStoredCaptures`
(500) files in `resource/jcks_anticheat/data/vision/`.
Run one dashboard instance per deployment.

## Development and tests

```bash
cd server-src && dotnet test
```

110 tests cover:

- the real Lua client's heartbeats verified by the C# server, plus tamper, replay and forgery
  rejection
- the crypto against Lua-generated vectors
- every validator, the rate limiter, the ledger's decay and its rule that client evidence alone never bans
- ban persistence, JSON parsing limits, config overrides
- the Claude request shape (structured output, image block, headers, fallbacks) and parsing of
  refusals, errors and OpenAI-compatible replies, all against a fake HTTP handler
- screenshot chunk reassembly
- repository consistency: every detection code documented in the threat matrix, every client
  flag in the catalog, settings schema and `config.json` covering each other, the manifest
  referencing only real files and the real DLL names, and no comments in code

The interop tests need `lua5.4` on `PATH`; set `JCKS_AC_SKIP_LUA=1` to skip them.

```bash
cd dashboard && npm run lint && npm run build
```

## What has and hasn't been verified

Verified in this repository:

- The OneSync event field names the server reads (`weaponDamageEvent`, `explosionEvent`,
  `clearPedTasksEvent`, `giveWeaponEvent` and the remove-weapon events) match the GTA V
  definitions in FiveM's `ServerGameState.cpp`. FiveM passes the sender as a string net ID; the
  handlers accept a string or a number.

- `givePedScriptedTaskEvent`, `onPedDeath`, and the sync values read with `IsPlayerUsingSuperJump`,
  `GetPlayerWeaponDamageModifier`, `GetPlayerWeaponDefenseModifier(_2)`, `GetPlayerMaxHealth`,
  `GetEntityCollisionDisabled`, `GetEntityAttachedTo`, `IsEntityVisible` and `GetEntityScript` were
  checked against FiveM's server source (`ServerGameState.cpp`, `ServerGameState_Scripting.cpp`,
  `SyncTrees_Five.h`). `onPedDeath` only exists on recent server artifacts.
- Every native the client Lua calls exists in `citizenfx/natives` or FiveM's `ext/native-decls`
  (checked by script).
- Both C# projects build with no warnings and the 125 tests pass.
- Every Lua file compiles with `luac5.4`. The heartbeat path runs for real under Lua 5.4 with
  stubbed FiveM natives.
- The dashboard type-checks and builds.
- In a browser test: the OAuth flow, all four pages, search, pagination, the ban dialog, the vision
  modal, and the mobile layout (no horizontal overflow), with no console errors.
- The real C# `DashboardBridge` pushed events into a running dashboard, and a ban issued in the UI
  came back to it with the player's identifiers.

Not verified, because no FiveM server or game client was available:

- The client detection modules calling real game natives.
- Resmon numbers.
- `screenshot-basic` capture.
- A real call to a vision API.

Run with `dryRun: true` and watch the Live view before enforcing anything.

The threat matrix comes from known cheat behaviours and the in-game symptoms they leave. It was not
compiled from live cheat-vendor research.
