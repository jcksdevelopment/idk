# Bazar & Item Flipping Simulator

Buy mystery junk at the bazaar, repair it on the workbench (time-based), and flip
it at the sell counter for profit. The game is built server-authoritative, with
session-locked saves and a receipt handler that can't double-grant.

* Rojo 7 project, strict Luau (`--!strict`) in every file, no external dependencies
* Security design: see **[THREAT_MATRIX.md](THREAT_MATRIX.md)**

## Quick start

1. Install the toolchain (pinned in `rokit.toml`):
   ```bash
   rokit install
   ```
   (or install [Rojo 7.4+](https://rojo.space) any other way, plus the Rojo Studio plugin)
2. Start the sync server from the repo root:
   ```bash
   rojo serve
   ```
3. In Roblox Studio, open a **Baseplate** place, then **Plugins → Rojo → Connect** (port `34872`, set in `default.project.json`).
4. Press **Play**. The server builds the bazaar map (three stalls and a spawn) at runtime.

To build a place file without Studio sync:
```bash
rojo build -o BazarFlippingSimulator.rbxlx
```

### DataStores in Studio
Turn on *Game Settings → Security → Enable Studio Access to API Services* to test
real persistence. If it's off, the server warns and falls back to an in-memory
`MockDataStore`, so the game still runs but nothing persists.

## Inserting Game Pass / Developer Product IDs

**All IDs live in one file: `src/shared/Config.luau`.**

1. Creator Dashboard → your experience → **Monetization → Passes**: create
   * **VIP Auto-Cleaner** → paste its ID into `Config.GamePasses.VIPAutoCleaner`
   * **+20 Inventory Capacity** → `Config.GamePasses.ExtraCapacity`
2. **Monetization → Developer Products**: create
   * **Instant Repair** → `Config.DevProducts.InstantRepair`
   * **2x Money Boost** → `Config.DevProducts.MoneyBoost2x`
   * **Starter Cash Pack** → `Config.DevProducts.CashPackSmall`

```lua
Config.GamePasses = {
	VIPAutoCleaner = 123456789,
	ExtraCapacity  = 123456790,
}
Config.DevProducts = {
	InstantRepair = 1234567891,
	MoneyBoost2x  = 1234567892,
	CashPackSmall = 1234567893,
}
```
An ID of `0` means "not configured". The server logs a warning on startup, the
shop shows **Soon**, and the server refuses to prompt that item. Robux prices are
fetched live with `GetProductInfo`, so set prices only on the dashboard. Shop
titles, descriptions and ribbons are in `Config.ShopDisplay`. Boost duration and
cash pack size are in `Config.Products`.

Set `Config.Debug.StudioGrantAllPasses = true` to test pass perks in Studio. It
has no effect in live servers.

## Project layout

```
default.project.json
src/
  shared/      → ReplicatedStorage.Shared
    Config.luau       ★ IDs, economy, timings, station layout
    Items.luau        item catalog (the only source of item value)
    Types.luau        shared type definitions
    Valuation.luau    pure price math (server-authoritative)
    Net.luau          single list of RemoteEvents
    Signal.luau, Format.luau
  server/      → ServerScriptService.Server   (init.server.luau = bootstrap)
    Services/
      DataService.luau         session-locked DataStore profiles
      MockDataStore.luau       Studio fallback
      RemoteGuard.luau         arg validation + rate limits for every remote
      FlagService.luau         suspicion score → kick
      AntiExploitService.luau  speed / teleport / fly-up checks
      GamePassService.luau     server-side pass ownership
      Rules.luau               capacity, repair slots, money multiplier
      SyncService.luau         per-player state snapshots + leaderstats
      WorldService.luau        map build + station proximity
      ItemService.luau         crates, rarity rolls (70/25/5), item creation
      RepairService.luau       timed repairs, Instant Repair, VIP auto-cleaner
      SellService.luau         id-only selling
      MonetizationService.luau ProcessReceipt + server-side prompts
  client/      → StarterPlayerScripts.Client  (init.client.luau = bootstrap)
    Controllers/  State, UI, Input, Repair, Proximity
    UI/           Theme, Create, HUD, InventoryPanel, BazaarPanel, CashShopPanel, Toast
```

## Game loop and monetization

| Feature | Behaviour |
|---|---|
| Mystery Junk Box ($25) | Trash 70% / Rare 25% / Legendary 5%, rolled on the server |
| Estate Sale Chest ($250) | 40 / 45 / 15 |
| Repair | Trash 8 s, Rare 30 s, Legendary 90 s. Timer persists across sessions (`os.time`) |
| Selling | Clean items sell at full value; dirty items at 35% |
| **Instant Repair** (Dev Product) | ⚡ on a card prompts a purchase that finishes that item. A purchase with no target becomes a reusable token |
| **2x Money Boost** (Dev Product) | 15 min, stacks up to 24 h, expiry tracked with `os.time()` |
| **VIP Auto-Cleaner** (Game Pass) | +2 workbench slots; repairs start and finish in the background |
| **+20 Inventory** (Game Pass) | Capacity 10 → 30 |

Controls: **I** inventory, **B** crates, **P** shop, **Backspace** close, **E** at a stall.
Gamepad: Y / X / B. Touch: HUD buttons.

## Development

```bash
stylua src                                  # format (stylua.toml)
selene src                                  # lint (selene.toml, roblox std)
rojo sourcemap -o sourcemap.json            # for luau-lsp strict type checking
luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau src
```

## Tuning checklist before launch
* `Config.Data.StoreName`: change it only when you deliberately want a data wipe.
* `Config.AntiExploit.*`: if your map has speed pads or vehicles, raise the tolerances or call `AntiExploitService.Grace(player, seconds)` around them.
* `Config.Stations.RequireProximity = false` turns it into a menu-only game, which removes the anti-AFK-farm proximity layer.
