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
| Game events | `giveWeaponEvent` / `removeWeaponEvent` / `removeAllWeaponsEvent` (always cancelled), `clearPedTasksEvent` against other players |
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

Kinds: `heal`, `armor`, `teleport`, `noclip`, `godmode`, `invisible`, `vision`, `ragdoll`, `camera`,
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

Everything lives in `resource/jcks_anticheat/config.json`: scoring thresholds and half-life, per-code
severity overrides, `ignore` codes (switched off entirely; the client stops sending them), `logOnly` codes, movement and damage limits, explosion and entity rules,
weapon/vehicle/object blacklists, honeypot event names, and vision and dashboard settings. Codes
and default severities are listed in `docs/THREAT_MATRIX.md`.

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

74 tests cover:

- the real Lua client's heartbeats verified by the C# server, plus tamper, replay and forgery
  rejection
- the crypto against Lua-generated vectors
- every validator, the rate limiter, the ledger's decay and its rule that client evidence alone never bans
- ban persistence, JSON parsing limits, config overrides
- the Claude request shape (structured output, image block, headers, fallbacks) and parsing of
  refusals, errors and OpenAI-compatible replies, all against a fake HTTP handler
- screenshot chunk reassembly

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

- Both C# projects build with no warnings and the 74 tests pass.
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
