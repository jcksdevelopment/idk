# Threat Matrix — Bazar & Item Flipping Simulator

Baseline assumption: **the client is fully compromised.** An exploiter can fire any
RemoteEvent with any arguments at any rate, read every client-side script, change
local memory and move their own character freely, because the client owns its
character's network physics. The server owns all state that matters.

| # | Threat | Attack | Countermeasure | Where |
|---|--------|--------|----------------|-------|
| 1 | **Event spoofing: instant repair** | Fire `CompleteRepair(id)` right after `StartRepair` | Server stamps `RepairEndsAt = os.time() + duration` on start. On complete, if `os.time() < RepairEndsAt` the request is **silently dropped**, and the player is **flagged** if it is earlier than the 2 s jitter tolerance | `RepairService.onCompleteRepair` |
| 2 | **Event spoofing: fake sell value** | `SellItem(id, 999999)` or edits the price shown in the UI | The remote accepts **exactly one** arg (a GUID). The price is computed on the server from the stored record, the static catalog and the server-tracked boost | `SellService`, `Valuation`, `RemoteGuard` arg-count check |
| 3 | Forged / foreign item IDs | Sends random GUIDs or other players' IDs | IDs are looked up only in **the caller's** session-locked inventory, and anything unknown is a no-op. IDs are server-generated GUIDs, validated with a strict pattern and a 36-char length | `RemoteGuard.Validators.ItemId` |
| 4 | Malformed arguments | Tables, Instances, NaN, 1 MB strings, extra args | Per-remote validators plus an exact arg-count check run before any handler. Violations are flagged | `RemoteGuard.Bind` |
| 5 | **Item duplication: double sell** | Fires `SellItem` many times in one frame or during lag | Check, remove and pay run in one **non-yielding** block. The second request finds no item | `SellService` |
| 6 | **Duplication across servers** | Joins server B while server A still holds the data, sells in both | **Session lock** in `UpdateAsync`: B cannot load until A releases or the lock goes stale (6 min without heartbeat). A server that loses the lock can never write (the transform cancels), so it deactivates the profile and kicks the player | `DataService.loadRecord/writeRecord` |
| 7 | **Leave mid-transaction** | Leaves exactly as a sale or purchase happens | All mutations are synchronous, so state is either fully before or fully after. On release the profile goes inactive **before** the final snapshot is copied, and later requests are rejected | `DataService.releaseProfile` |
| 8 | **Robux purchase lost** | DataStore outage during purchase | `ProcessReceipt` returns `PurchaseGranted` **only after** a save containing the grant commits. Anything else returns `NotProcessedYet`, and Roblox redelivers on rejoin or the next purchase | `MonetizationService.processReceipt` |
| 9 | **Robux purchase granted twice** | Receipt redelivered, or callback runs on two servers | `PurchaseId` is recorded in the same atomic block as the grant and persisted with it. A server without the active lock has no profile, so it returns `NotProcessedYet` | `MonetizationService`, session lock |
| 10 | Fake game pass ownership | Client claims ownership | Ownership comes only from `UserOwnsGamePassAsync` and the server-side `PromptGamePassPurchaseFinished` | `GamePassService` |
| 11 | Data corruption | NaN or inf cash from a bug, bad schema | `sanitize()` on load, and `validateForSave()` refuses to write invalid data. An unreadable record is never overwritten; the player is kicked so the record can be recovered | `DataService` |
| 12 | **Auto-clickers / macros** | Spams `BuyCrate` and `SellItem` | Token bucket per remote **and** a global budget per player. Sustained spam adds flag weight; occasional human bursts do not | `RemoteGuard` |
| 13 | **AFK auto-farm** | Macro buys, repairs and sells from one spot | Buy, start-repair and sell require **standing at the station** (server distance check plus leeway). Remote calls from out of range are flagged | `WorldService.IsNear` |
| 14 | **Speed hack** | Raises WalkSpeed locally or uses CFrame walking | The server's WalkSpeed is authoritative because client changes don't replicate. Displacement per 0.25 s is checked against it, and three straight violations rubber-band the player to the last valid position and flag them | `AntiExploitService` |
| 15 | **Teleport / fly-up** | Teleports to a station, or rises vertically | A jump of more than 80 studs, or a rise of more than 25 studs, in one interval is corrected immediately and flagged | `AntiExploitService` |
| 16 | Remote flood / server DoS | Thousands of events per second | Global bucket drops excess traffic at the first check | `RemoteGuard` |
| 17 | RemoteFunction hang | Exploiter never returns from `InvokeClient` | The game uses no RemoteFunctions; server → client traffic is fire-and-forget events | `Net` |
| 18 | Purchase prompt spam | Fires `PromptProduct` in a loop | Rate-limited (1/s), keys whitelisted, and prompts sent from the server | `MonetizationService` |
| 20 | **Fake quest / XP progress** | Fires events to complete quests or level up | No remote reports progress. Progress and XP are emitted only by the server inside already-validated actions (crate bought, repair finished, item sold) | `ProgressService.Record` |
| 21 | **Double-claiming rewards** | Spams `ClaimDaily` / `ClaimQuest` / `ClaimCollection` | The claim flag is set in the same non-yielding block that grants the reward. Days are UTC from `os.time()`, never from the client clock | `ProgressService` |
| 22 | **Scrub auto-clicker** | Macro taps the scrub button | Each tap removes at most 0.5 s, capped at 60% of the repair. Taps faster than 8/s are dropped (silently, so excited kids are never flagged) | `RepairService.onScrub`, `RemoteGuard` `Silent` |
| 23 | Forged settings | Sends odd keys/values to `SetSetting` | Keys whitelisted; values type-checked per key | `ProgressService.onSetSetting` |
| 24 | Locked crate | Buys a high-level box early | Level re-checked on the server from saved XP | `ItemService.onBuyCrate` |
| 25 | **Wheel spam / rigging** | Spams `SpinWheel` or tries to choose the prize | The cooldown is stored in the profile (`LastSpinAt`) and set atomically with the grant. The prize is rolled by server RNG, and the client only animates to the announced index | `ProgressService.onSpinWheel` |
| 26 | Fake achievements / titles | Sends `SetTitle` for a locked title | Achievements unlock only from server stats. `SetTitle` accepts only unlocked ids (or "") | `ProgressService` |
| 27 | Rebirth abuse | Rebirths without meeting the requirement | Level + cash re-checked on the server; reset and bonus applied in one block; capped at `MaxRebirths` | `ProgressService.onRebirth` |
| 28 | Fake friend bonus | Claims friends | Friendship checked by the server (`IsFriendsWith`); bonus capped at +30% | `FriendService` |
| 29 | Fusion dupes | Fuses with forged/foreign pets or the same pet twice | Only ids in the caller's profile; the two consumed pets are distinct from the base and match kind + stars; removal and upgrade happen in one block | `PetService.onFusePets` |
| 30 | Code abuse | Redeems a code twice or brute-forces codes | Redeemed codes are stored in the profile and marked in the same block as the grant. `RedeemCode` is limited to ~1 try per 3 s, so guessing is pointless; event-only codes are re-checked by date on the server | `ProgressService.onRedeemCode` |
| 31 | Free box farming | Buys the free box repeatedly | The free price applies only while `LastFreeBoxDay` differs from the server's UTC day; it is set in the same block as the purchase | `ItemService.onBuyCrate` |
| 32 | Fake group / Premium bonus | Claims membership | `Player:IsInGroup` and `Player.MembershipType` are read on the server only | `SocialService` |
| 33 | Weekly challenge abuse | Claims twice or reports progress | Progress only from server events; claim flag set atomically with the grant; week derived from server UTC day | `ProgressService.onClaimWeekly` |
| 34 | Badge spam | Triggers badge awards | Badges are awarded only by the server on achievement unlock; per-session de-dup + UserHasBadgeAsync check | `BadgeAwardService` |
| 35 | Request spoofing | Claims a request for any item | The wanted item, expiry and multiplier live in the server profile; the bonus applies only when the sold, server-owned item matches and is clean, then the request clears atomically | `RequestService.TryFulfill` |
| 36 | Upgrade abuse | Buys upgrades without cash or past max | Price and max come from `Config.Upgrades` on the server; cash check, payment and level-up in one block | `UpgradeService` |
| 37 | Market skipping | Buys Vault/Galaxy boxes early | `UnlockRebirths` re-checked against the saved New Start count on the server | `ItemService.onBuyCrate` |
| 38 | Pass effects without owning the pass | Claims DoubleMoney / AutoSell / PocketStalls etc. | Every pass effect checks `GamePassService.Has` on the server (ownership from UserOwnsGamePassAsync / server purchase event). Pocket Stalls intentionally bypasses the stall-distance check only for owners | `Rules`, `WorldService.IsNear`, `SellService` |
| 39 | Starter Pack farming | Buys the one-time pack repeatedly | Server refuses to prompt it once `StarterPackBought`; a receipt that still arrives is honoured (paid receipts must be granted) | `MonetizationService` |
| 19 | Client code theft | Decompiles LocalScripts | The client holds no secrets or authority: only rendering and requests | architecture |

## Flag scoring
Each detection adds weight (2–20). The score decays at 0.5/s, and the player is
kicked at 100. Totals are persisted to `Moderation.TotalFlags` in the profile for
review. One-off false positives such as lag spikes or clock jitter decay away.

## Known residual risks
- **Hover/fly at constant height** isn't detected; the vertical check catches only fast rises. Add raycast ground checks if your map needs it.
- **Physics flinging** by other players can trip the speed check. It only rubber-bands, and decay prevents kicks.
- A final save that fails during a **total DataStore outage** loses that session's progress since the last autosave (≤ 60 s). It can't duplicate anything. The lock then expires after `LockStaleSeconds` (6 min) before the player can load elsewhere.
- Macros that physically walk between stations are indistinguishable from humans. Rate limits and economy tuning set their ceiling.
