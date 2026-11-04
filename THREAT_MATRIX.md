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
