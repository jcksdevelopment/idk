# JCKS Anticheat Threat Matrix

Each row is a cheat capability, how it shows up in game state, and the code that looks for it.
IDs match the `code` field used in heartbeat flags, server violations, and the dashboard.

Layers:

- **C**: client scanner (Lua). The scanner runs on the cheater's machine, so a capable menu can patch or
  spoof it. Treat it as a signal source, never as the final authority.
- **S**: server authority (C#). It uses only data the server observes itself (OneSync state,
  game events, network traffic), so the client cannot lie about it.
- **H**: heartbeat integrity. If the scanner is stopped or tampered with, the heartbeat fails.

Severity is the score added per hit. Scores decay over time. Thresholds for kick and ban
live in `config.json`, not in code. Codes in `scoring.dropImmediately` (default `HB_INVALID`,
`HB_MISSING`, `NET_FLOOD`) disconnect the player at once regardless of score, but never ban alone.

## Player

| Code | Capability | Observable symptom | Layer | Implementation | Sev |
|---|---|---|---|---|---|
| `PLY_GODMODE_FLAG` | Godmode (invincible flag) | `GetPlayerInvincible`/`GetPlayerInvincible_2` true, or `GetEntityCanBeDamaged` false, while server hasn't authorised it; server reads `GetPlayerInvincible` from sync | C+S | `client/detections/player.lua`, server state tick | 40 |
| `PLY_GODMODE_PROOFS` | Semi-godmode (proofs, defense) | `GetEntityProofs` returns bullet/explosion/fire/melee proofs set; weapon defense modifier below 1.0 (server reads `GetPlayerWeaponDefenseModifier`/`_2` from sync) | C+S | `player.lua`, `weapon.lua`, `PlayerFlagsValidator` | 35 |
| `PLY_HEALTH_REGEN` | Health lock / instant regen | Health rises faster than natural regen with no server-authorised heal | C+S | `player.lua`, `PlayerStateValidator` | 25 |
| `PLY_ARMOR_REGEN` | Armour lock / instant refill | Armour rises with no server-authorised armour event | C+S | `player.lua`, `PlayerStateValidator` | 25 |
| `PLY_HEALTH_CAP` | Max-health tampering | Health > `GetEntityMaxHealth` or max health > configured cap; server reads `GetPlayerMaxHealth` | C+S | `player.lua`, `PlayerFlagsValidator` | 30 |
| `PLY_DAMAGE_ABSORB` | Semi-godmode (absorbs hits) | Server sees confirmed `weaponDamageEvent` hits, but victim health never drops | S | `DamageValidator` | 30 |
| `PLY_NO_RAGDOLL` | No ragdoll | `CanPedRagdoll` false while on foot and not authorised | C | `player.lua` | 15 |
| `PLY_SUPERJUMP` | Super jump | Jump apex height above ground > 3.5 m, or `IsPedJumping` with vertical speed > 9 m/s; server sees the super-jump flag in sync (`IsPlayerUsingSuperJump`) | C+S | `player.lua`, `PlayerFlagsValidator` | 30 |
| `PLY_SPEED_FOOT` | Speedhack (on foot) | Ped speed > 12 m/s on foot, not falling, not ragdolled | C+S | `player.lua`, `MovementValidator` | 30 |
| `PLY_STAMINA` | Infinite stamina | Sprinting for > 25 s with stamina still at 100 | C | `player.lua` | 10 |
| `PLY_VISION` | Thermal / night vision | `GetUsingseethrough` or `GetUsingnightvision` true without an authorised item | C | `player.lua` | 15 |
| `PLY_ESP_BLIPS` | Player ESP through map blips | At least `client.espBlipPlayers` other players' peds carry a blip (`GetBlipFromEntity`) that no shielded resource created with `AddBlipForEntity`; the blips are removed. Needs the shield | C | `player.lua`, `shield.lua` | 25 |
| `PLY_INVISIBLE` | Invisibility (on foot or in an invisible vehicle) | `IsEntityVisible` false or alpha < 50 on the ped on foot, or on the vehicle the player drives, while not authorised; both are made visible again | C+S | `player.lua`, `vehicle.lua`, server state tick | 30 |
| `PLY_TINY_PED` | Tiny ped | Ped config flag 223 (shrink) set without a `tiny` grant | C | `player.lua` | 30 |
| `PLY_SELF_REVIVE` | Self-revive | Player goes from dead to alive without a `heal`/`revive` grace (trusted ambulance/spawn resources grant it through the shield) | C | `player.lua` | 35 |
| `PLY_SPECTATE` | Spectate other players | `NetworkIsInSpectatorMode` true without an admin grant (`spectate`) | C | `player.lua` | 35 |
| `PLY_PED_MODEL` | Ped model swap | Server sees a ped model outside the allow list | S | `EntityValidator` | 20 |

## Movement

| Code | Capability | Observable symptom | Layer | Implementation | Sev |
|---|---|---|---|---|---|
| `MOV_FREECAM` | Freecam | Gameplay cam > 30 m from ped (outside vehicle/cutscene/spectate) | C | `client/detections/movement.lua` | 25 |
| `MOV_NOCLIP_COLLISION` | NoClip (collision off) | `GetEntityCollisionDisabled` true on ped or vehicle; server sees it on a ped that is on foot and not attached for `server.collisionStreakSeconds` | C+S | `movement.lua`, `PlayerFlagsValidator` | 40 |
| `MOV_NOCLIP_FLOAT` | NoClip (flying) | > 5 m above ground with near-zero vertical velocity for > 3 s, not in aircraft/parachute | C+S | `movement.lua`, `MovementValidator` | 35 |
| `MOV_NOCLIP_ZVEL` | NoClip (impossible Z) | Ascending > 15 m/s on foot (gravity forbids it) | C+S | `movement.lua`, `MovementValidator` | 35 |
| `MOV_BRING_ALL` | "Bring all players" | 3+ players teleported onto the same spot in one tick; the victims' `MOV_TELEPORT` is dropped and the non-teleported player standing there is reported | S | `MassTeleportDetector` | 50 |
| `MOV_TELEPORT` | Teleport | Server sees displacement over the tick that implies speed > class max, with no authorised teleport | S | `MovementValidator` | 40 |
| `MOV_SPEED_VEH` | Speedhack (vehicle) | Vehicle speed > class cap (land 110 m/s, air 160 m/s) | S | `MovementValidator` | 30 |

## Weapon

| Code | Capability | Observable symptom | Layer | Implementation | Sev |
|---|---|---|---|---|---|
| `WPN_BLACKLIST` | Blacklisted weapon spawn | Ped holds a weapon on the blacklist (client check plus `giveWeaponEvent` and server `GetSelectedPedWeapon`) | C+S | `weapon.lua`, `AnticheatScript.cs` | 50 |
| `WPN_GIVE_ALL` | "Give all weapons" | Holding more than `maxWeapons` (25) stock weapons at once | C | `weapon.lua` | 40 |
| `WPN_PROJECTILE_ORIGIN` | Magic projectiles / rockets at players | `startProjectileEvent` starting > 12 m from the shooter (on foot), or fired "as" another player's ped. Cancelled. | S | `GameEventValidator` | 45 |
| `WPN_PROJECTILE_SPAM` | Projectile spam | More than 20 projectiles in 10 s | S | `GameEventValidator` | 40 |
| `WPN_FIRE_PLAYER` | Set players on fire | `fireEvent` with a fire attached to another player's ped. Cancelled. | S | `GameEventValidator` | 45 |
| `WPN_FIRE_SPAM` | Fire spam | More than 10 fires in 10 s | S | `GameEventValidator` | 40 |
| `WPN_GIVE_EVENT` | Give or strip weapons | `giveWeaponEvent`, `removeWeaponEvent` or `removeAllWeaponsEvent` from a client (always malicious under OneSync; cancelled) | S | `AnticheatScript.cs` | 50 |
| `WPN_DMG_MODIFIER` | Damage multiplier | `GetPlayerWeaponDamageModifier`/`Melee…` ≠ `expectedDamageModifier` (client and server sync), `GetWeaponDamageModifier` on the weapon in hand above `client.weaponDamageModifierMax`, or `weaponDamageEvent.weaponDamage` > baseline×1.5 | C+S | `weapon.lua`, `PlayerFlagsValidator`, `DamageValidator` | 40 |
| `WPN_MASS_KILL` | Kill-all / mass kill | One player kills more than `damage.maxKillsPer10s` players in 10 s (server `onPedDeath`, any weapon, explosion or vehicle) | S | `MassKillTracker` | 45 |
| `WPN_RANGE` | Out-of-range hits | Hit distance > weapon effective range × 1.25 | S | `DamageValidator` | 25 |
| `WPN_AIM_ANGLE` | Silent aim | Shooter's facing vs. vector to victim > 60° on a confirmed hit | S | `DamageValidator` | 30 |
| `WPN_TRAJECTORY` | Magic bullet / fabricated hits | Reported bullet impact direction (`impactDirX/Y/Z`) deviates > 45° from the shooter→victim line | S | `DamageValidator` | 20 |
| `WPN_AIM_SNAP` | Aimbot snap | Camera rotation jumps > 70° in one frame within 150 ms before a shot | C | `weapon.lua` | 20 |
| `WPN_HEADSHOT_RATIO` | Aimbot (statistical) | Headshot ratio > 70% over ≥ 25 ranged hits | S | `DamageValidator` | 30 |
| `WPN_TRIGGERBOT` | Triggerbot | Shot reaction time < 60 ms after crosshair acquires a ped, repeatedly | C | `weapon.lua` | 15 |
| `WPN_RAPID_FIRE` | Rapid fire | Server-observed damage events per weapon exceed the weapon's max fire rate × 1.5 | S | `DamageValidator` | 30 |
| `WPN_INFINITE_AMMO` | Infinite ammo | Shooting for > 2 s and clip count never decreases | C | `weapon.lua` | 20 |
| `WPN_EXPLOSIVE_AMMO` | Explosive / fire ammo | `explosionEvent` from a player with `EXP_TAG_BULLET` (18), or more than 4/s or 12/10 s | S | `ExplosionValidator` | 50 |
| `WPN_EXPLOSION_BLAME` | "Explode player" blamed on someone else | A weapon explosion (grenade, rocket, sticky bomb, molotov, explosive ammo, ...) whose `ownerNetId` belongs to a different player than the sender. Destroyed-vehicle/object explosions are excluded. Cancelled. | S | `ExplosionValidator` | 35 |
| `WPN_EXPLOSION_BLACKLIST` | Explosion spam | Blacklisted explosion type, or invisible/no-sound/cam-shake-0 explosion | S | `ExplosionValidator` | 50 |

## Vehicle

| Code | Capability | Observable symptom | Layer | Implementation | Sev |
|---|---|---|---|---|---|
| `VEH_SPAWN` | Vehicle spawn bypass | `entityCreating` with a blacklisted model, or > 5 vehicles in 10 s from one owner | S | `EntityValidator` | 40 |
| `ENT_SPAWN_FLOOD` | Object/ped spam | > 15 entities in 10 s from one owner | S | `EntityValidator` | 45 |
| `ENT_UNKNOWN_SCRIPT` | Entities spawned by an injected menu under a made-up resource name | A script-created entity whose creating script (`GetEntityScript`, from the entity's sync data) matches no resource on the server. Log-only by default; `entities.blockUnknownScript` cancels the spawn | S | `EntityScriptCheck` | 35 |
| `ENT_ATTACH_PLAYER` | Props/cages/vehicles stuck on other players | More than `entities.maxAttachedToOthers` objects or vehicles first owned by one player are attached (`GetEntityAttachedTo`) to other players' peds; they are deleted | S | `AttachmentWatch` | 40 |
| `VEH_HANDLING` | Handling edit | Handling floats drift from the baseline captured on entering | C | `vehicle.lua` | 30 |
| `VEH_POWER` | Power/torque boost | `GetVehicleCheatPowerIncrease` > 1.0 | C | `vehicle.lua` | 30 |
| `VEH_TOP_SPEED` | Top-speed boost | `GetVehicleTopSpeedModifier` above `client.topSpeedModifierMax` percent (-1 means unset) | C | `vehicle.lua` | 30 |
| `VEH_GRAVITY` | Vehicle gravity change (wall-ride, fly) | `GetVehicleGravityAmount` differs from 9.8 by more than `client.gravityTolerance` | C | `vehicle.lua` | 30 |
| `VEH_DMG_MODIFIER` | Ramming damage boost | `GetPlayerVehicleDamageModifier` above `client.vehicleDamageModifierMax` | C | `vehicle.lua` | 30 |
| `VEH_RAINBOW` | Rainbow vehicle | Paint colour changes 12+ times within 5 s without a `vehicle` grant | C | `vehicle.lua` | 20 |
| `VEH_HIJACK` | Hijack / warp into another player's vehicle | Driver seat of a locked vehicle another online player spawned, without a `vehicle` grant | S | `VehicleOwnership` | 40 |
| `VEH_REPAIR` | Instant vehicle repair ("fix vehicle") | Engine or body health jumps from < 600 to full in 0.5 s without a `vehicle` grant, while this client owns the vehicle (a mechanic repairing it from another client is not counted) | C | `vehicle.lua` | 25 |
| `VEH_PLATE` | Plate changer | Plate text changes while driving the same vehicle without a `vehicle` grant | C | `vehicle.lua` | 20 |
| `VEH_GODMODE` | Vehicle godmode | `GetEntityCanBeDamaged` false on own vehicle, or every damage proof set | C | `vehicle.lua` | 30 |

## Network & execution

| Code | Capability | Observable symptom | Layer | Implementation | Sev |
|---|---|---|---|---|---|
| `NET_RATE` | Event flood / spoofing | Per-player token bucket on net events is exhausted | S | `RateLimiter` | 20 |
| `NET_CLEAR_TASKS` | Kick players out of vehicles / freeze them | `clearPedTasksEvent` aimed at another player's ped (cancelled) | S | `AnticheatScript.cs` | 40 |
| `NET_GIVE_TASK` | Force animations or tasks on other players | `givePedScriptedTaskEvent` aimed at another player's ped (cancelled). NPC peds are not counted | S | `AnticheatScript.cs` | 40 |
| `NET_FLOOD` | Event flood / spam triggers | 40+ rate-limited events within 10 s: the player is disconnected at once | S | `AnticheatScript.cs` (`Guard`) | 40 |
| `NET_PTFX_SPAM` | Particle spam (crash/blind players) | `ptFxEvent` over 40 per 10 s, scale > 5, or attached to another player. Cancelled. | S | `GameEventValidator` | 35 |
| `NET_EVENT_SPAM` | Spamming money/item server events (executor loops) | A server event listed in `protectedEvents` triggered more times per minute than its limit. FiveM still runs the event's own handler; it blocks the trigger when that handler calls `exports.jcks_anticheat:CheckEvent` | S | `AnticheatScript.cs` | 30 |
| `NET_EVENT_ZONE` | Triggering job/shop/payout events from anywhere (executor) | A server event listed in `eventZones` triggered while the player's server-side position is outside every configured radius (the position check from FiveM's "Secure your events" guide). Blocked by `CheckEvent` in the event's handler | S | `EventZones` | 30 |
| `NET_CHAT_SPOOF` | Fake chat messages as another player | `_chat:messageEntered` author differs from the sender's name (the cfx chat client always sends the real name). The message is stopped by cancelling the chat resource's local `chatMessage` event, which the chat resource checks. | S | `AnticheatScript.cs` | 40 |
| `NET_HONEYPOT` | Event spoofing (dumped triggers) | Client fires a decoy event that legitimate code never fires | S | `AnticheatScript.cs` (honeypot events) | 60 |
| `HB_MISSING` | Scanner killed or never started | No valid heartbeat for > 20 s, or in the world for > 120 s without the `jcks_anticheat:hello` handshake | H | `HeartbeatManager` | 60 |
| `HB_INVALID` | Heartbeat forgery/replay | MAC mismatch, sequence replay, or stale challenge | H | `HeartbeatManager` | 60 |
| `HB_STATE_MISMATCH` | Hooked getters / forged heartbeat state | Health, armour or position the client reports differs from the server's OneSync view for 3 heartbeats in a row (e.g. `GetEntityHealth` hooked to hide godmode) | H | `StateConsistencyValidator` | 30 |
| `EXE_RESOURCE_COUNT` | Executor `GetNumResources` spoof | Client resource count/list ≠ server's started list | C | `integrity.lua` | 40 |
| `EXE_RESOURCE_INJECT` | Injected resource | Unknown resource starts on the client | C | `integrity.lua` | 50 |
| `EXE_COMMAND_INJECT` | Injected command handlers | `GetRegisteredCommands` contains a name the server didn't register | C | `integrity.lua` | 40 |
| `EXE_MENU_TEXTURE` | Menu textures streamed in | A texture dictionary from the operator's `textureBlacklist` is loaded | C | `integrity.lua` | 50 |
| `EXE_LUA_INJECT` | Lua executor / Lua mod menu injected into a resource | The shield (installed into every resource) sees a guarded function (`TriggerServerEvent`, `CreateVehicle`, `GiveWeaponToPed`, `SetEntityCoords`, `AddExplosion`, `SetEntityInvincible`, `Citizen.InvokeNative`, ...) called with a stack frame from a chunk that isn't a resource file, or a new global function defined by such a chunk | C | `shield/shield.lua` | 60 |
| `EXE_SHIELD_TAMPER` | Menu unhooking the shield | A shield wrapper in some resource was replaced (natives restored to bypass it) | C | `shield/shield.lua` | 60 |
| `EXE_GLOBAL_TAMPER` | Native hooking from executor | Canary natives/globals in the scanner's environment were swapped | C | `integrity.lua` | 50 |
| `NUI_DEVTOOLS` | NUI devtools opened | NUI page detects devtools (debugger timing and console getter traps) | C | `html/index.html`, `integrity.lua` | 40 |
| `CHK_ERROR` | Scanner tampering (partial) | A client check threw an error, or a heartbeat carried an unknown flag code | C | `client/main.lua`, `AnticheatScript.cs` | 5 |
| `NUI_FRAME_INJECT` | Injected NUI frame | NUI page sees an unknown `iframe`/`script` via `MutationObserver` | C | `html/index.html` | 40 |
| `VIS_AI_FLAG` | Visual overlay (ESP, FOV circle, menu) | AI vision verdict says `cheat` with confidence ≥ 0.8 | S | `AIVisionEvaluator` | 30 (review queue, never auto-ban) |

## Known gaps

- Client checks can be patched by any menu that hooks natives. That's why every high-severity
  outcome needs a server-side signal (S) or a heartbeat failure (H).
- Silent aim that doesn't change shooter orientation looks like legitimate aiming from where the
  server sits. `WPN_AIM_ANGLE` only catches gross cases. The statistical check (`WPN_HEADSHOT_RATIO`)
  covers the rest over time.
- External ESP that draws on a transparent overlay window is invisible to a game screenshot.
  The AI vision layer only sees in-game overlays.

## External reports

Other server resources can report their own findings with `exports.jcks_anticheat:ReportViolation(source, code, details)`.
The code is prefixed with `EXT_`, scores 25 points by default (override in `scoring.severity`) and is
treated as server evidence, since only server scripts can call the export. At most 10 reports per
player per code per minute are accepted.
