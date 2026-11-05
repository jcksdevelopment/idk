# Bazar & Item Flipping Simulator

Buy mystery junk at the bazaar, repair it on the workbench (time-based), and flip
it at the sell counter for profit. The game is built server-authoritative, with
session-locked saves and a receipt handler that can't double-grant.

**Kid-friendly edition (v2):** an interactive tutorial with a guide arrow, levels &
XP, daily quests, a 7-day login gift, a collection book, ✨ shiny items, a
"scrub" tap mini-game, sounds and confetti, a decorated market plaza, and full
**Slovak + English** UI (auto-detected, switchable in Settings). Monetization is
pressure-free: no pop-up upsells by default, and everything sold for Robux can
also be earned by playing.

> 🇸🇰 **Rýchly štart:** `rojo serve` → v Roblox Studiu plugin Rojo → *Connect* →
> *Play*. ID herných pasov a produktov vlož do `src/shared/Config.luau`. Hra sa
> automaticky prepne do slovenčiny pre hráčov so slovenským (alebo českým)
> nastavením Robloxu; jazyk sa dá zmeniť v ⚙️ Nastaveniach.

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
    Config.luau       ★ IDs, economy, quests, rewards, sounds, station layout
    Items.luau        item catalog (the only source of item value)
    Locale.luau       all player-facing text (English + Slovak)
    Progression.luau  level curve
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
      Rules.luau               capacity, repair slots, money multiplier, cash/boost
      ProgressService.luau     XP/levels, daily quests, login gift, collection, tutorial, settings
      ProgressViews.luau       read-only quest/daily/achievement projections for snapshots
      FriendService.luau       friends-in-server bonus (server-side IsFriendsWith)
      LeaderboardService.luau  global top-10 board
      SyncService.luau         per-player state snapshots + leaderstats
      WorldService.luau        map build + station proximity
      ItemService.luau         crates, rarity rolls (70/25/5), item creation
      RepairService.luau       timed repairs, Instant Repair, VIP auto-cleaner
      SellService.luau         id-only selling
      MonetizationService.luau ProcessReceipt + server-side prompts
  client/      → StarterPlayerScripts.Client  (init.client.luau = bootstrap)
    Controllers/  State, UI, Input, Repair, Proximity, Sound, Guide (tutorial beam), Overhead (name tags)
    UI/           Theme, Create, Effects, Toast, HUD, InventoryPanel, BazaarPanel,
                  RewardsPanel, IndexPanel, TrophyPanel, WheelPanel, CashShopPanel, SettingsPanel
```

## Game loop and monetization

| Feature | Behaviour |
|---|---|
| Mystery Junk Box ($25, level 1) | Common 70% / Rare 25% / Legendary 5%, rolled on the server |
| Estate Sale Chest ($250, level 3) | 40 / 45 / 15 |
| Royal Treasure ($1,500, level 8) | 15 / 50 / 35 |
| ✨ Shiny | 3% of found items, worth 2.5× |
| Repair | Common 8 s, Rare 30 s, Legendary 90 s. Timer persists across sessions (`os.time`) |
| 🧽 Scrub | Tap a repairing item (card or workbench slot): −0.5 s per tap, at most 60% of the repair, max 8 taps/s |
| Levels & XP | XP for opening, repairing and selling; each level gives bonus cash, every 5 levels +2 bag slots, levels unlock bigger boxes |
| 📜 Daily quests | 3 per day (UTC), picked from a pool of 9, with cash/token/boost/XP rewards |
| 🎁 Login gift | 7-day streak calendar (day 7 is the big one) |
| 📖 Collection book | Discover every item of a rarity to claim a reward; shinies are tracked too |
| Tutorial | 4 steps with a glowing beam + arrow to the next stall; reward on completion |
| 🏆 Trophies | 13 achievements that unlock automatically, each with a reward and a **title** shown above your head to everyone |
| 🔄 New Start (rebirth) | From level 15 + $25,000 (rises each time): reset cash & level, keep items/book/trophies, **+25% money forever** per New Start. Two-tap confirm |
| 🎡 Lucky Wheel | One **free** spin every 4 h (never for Robux); 7 prizes, cash scales with level; the server picks, the client only animates |
| ✨ Pet fusion | 3 identical pets (same kind and stars) fuse into one with +1 ⭐ (max 2): ×2 bonus at ⭐, ×4 at ⭐⭐ |
| 👫 Friend bonus | +10% money per Roblox friend in the same server (max +30%) |
| 📊 Leaderboard | Top 10 lifetime earners on a board in the plaza (OrderedDataStore, refreshed every 2 min) |
| Selling | Clean items sell at full value; dirty items at 35% |
| **Instant Repair** (Dev Product) | ⚡ on a card prompts a purchase that finishes that item. A purchase with no target becomes a reusable token |
| **2x Money Boost** (Dev Product) | 15 min, stacks up to 24 h, expiry tracked with `os.time()` |
| **VIP Auto-Cleaner** (Game Pass) | +2 workbench slots; repairs start and finish in the background |
| **+20 Inventory** (Game Pass) | Capacity 10 → 30 |

Controls: **I** bag, **B** boxes, **Q** quests, **C** collection book, **T** trophies, **L** lucky wheel, **P** shop,
**Backspace** close, **E** at a stall. Gamepad: Y / X / L1 / R1 / B. Touch: HUD buttons.

### Kid-friendly defaults
* `Config.Monetization.ShowUpsells = false`: no "+2 slots" / "+20 slots" / "⚡R$" nudges. The shop is still one tap away.
* The shop shows a note that Robux purchases are optional and to ask a grown-up.
* Mystery boxes are bought **only with in-game cash**, never Robux, and their odds are always shown.
* Sounds use built-in Roblox sounds; swap in your own in `Config.Sounds` and add background music via `Config.Sounds.Music.Id`.

### Adding a language
Add a table to `src/shared/Locale.luau`, register it in `tables`, and add its code to `Config.Languages`.

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
