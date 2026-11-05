using System;
using System.Collections.Generic;
using System.Linq;
using CitizenFX.Core;
using JcksAnticheat.Core.Audit;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Heartbeat;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Validation;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        public const string AdminAce = "jcks_anticheat.admin";

        private readonly string _settingsEvent = HeartbeatManager.RandomEventName();
        private readonly string _panelOpenEvent = HeartbeatManager.RandomEventName();
        private readonly string _panelActionEvent = HeartbeatManager.RandomEventName();

        private string _schemaJson = "{}";

        private void RegisterSettings()
        {
            _schemaJson = LoadResourceFile(_resource, "settings.schema.json") ?? "{}";
            RegisterCommand("jac", new Action<int, List<object>, string>(OnJacCommand), false);
            EventHandlers[_panelActionEvent] += new Action<Player, string, string>(OnPanelAction);
            PushSettingsToDashboard();
        }

        private static bool IsAdmin(int source) => source == 0 || IsPlayerAceAllowed(source.ToString(), AdminAce);

        private void OnJacCommand(int source, List<object> args, string raw)
        {
            void Reply(string msg)
            {
                if (source == 0) Log(msg);
                else Players[source]?.TriggerEvent("chat:addMessage", new { args = new[] { "JCKS Anticheat", msg } });
            }

            if (!IsAdmin(source)) { Reply("You don't have permission (" + AdminAce + ")."); return; }
            var sub = args.Count > 0 ? args[0]?.ToString()?.ToLowerInvariant() : "status";
            var actor = source == 0 ? "console" : (Players[source]?.Name ?? "#" + source);

            switch (sub)
            {
                case "reload":
                    Reply(ReloadFromDisk(actor));
                    break;
                case "panel":
                    if (source == 0) { Reply("The panel opens in game: use /jac panel as a player."); break; }
                    OpenPanel(source, null, null);
                    break;
                case "dryrun":
                    var on = args.Count > 1 && (args[1]?.ToString() == "on" || args[1]?.ToString() == "true");
                    var edited = AnticheatConfig.Parse(MiniJson.Serialize(_cfg.ToJson()));
                    edited.DryRun = on;
                    Reply(Apply(edited, actor, save: true));
                    break;
                case "antidump":
                    if (source != 0) { Reply("Run anti-dump commands from the server console."); break; }
                    Reply(AntiDumpCommand(args));
                    break;
                case "integrations":
                    if (source != 0) { Reply("Run integration commands from the server console."); break; }
                    Reply(IntegrationsCommand(args.Count > 1 ? args[1]?.ToString() ?? "list" : "list"));
                    break;
                case "scan":
                    if (source != 0) { Reply("Run scan commands from the server console."); break; }
                    Reply(BackdoorCommand(args));
                    break;
                case "shield":
                    if (source != 0) { Reply("Run shield commands from the server console."); break; }
                    Reply(ShieldCommand(args.Count > 1 ? args[1]?.ToString() ?? "status" : "status"));
                    break;
                case "info":
                case "reset":
                {
                    int target = args.Count > 1 ? ToInt(args[1]) : 0;
                    var tp = target > 0 ? Players[target] : null;
                    if (tp == null) { Reply("Usage: /jac " + sub + " <server id of an online player>"); break; }
                    if (sub == "reset")
                    {
                        _ledger.Forget(target);
                        _recent.Forget(target);
                        Log($"score of {tp.Name} (#{target}) reset by {actor}");
                        Reply($"Score of {tp.Name} (#{target}) reset to 0.");
                        break;
                    }
                    var recent = _recent.Of(target);
                    var hb = _heartbeats.HasSession(target) ? "ok" : "no session";
                    Reply($"{tp.Name} (#{target}): score {_ledger.ScoreOf(target):F0}, heartbeat {hb}, last: " +
                          (recent.Count == 0 ? "nothing" : string.Join(", ", recent.AsEnumerable().Reverse().Take(6).Select(r => $"{r.code}+{r.severity} {(int)(DateTime.UtcNow - r.at).TotalMinutes}m ago"))));
                    break;
                }
                case "audit":
                    Reply(RunAudit());
                    break;
                case "status":
                default:
                    var (shielded, withClient) = ShieldCoverage();
                    Reply($"license={(_licenseRequired ? (_licensed ? "valid" : "INVALID") : "dev build")}, shield={shielded}/{withClient} resources, " +
                          $"integrations={_integrations.Count} rules, countermeasures={(_cfg.Countermeasures.Enabled ? "on" : "off")}, backdoor findings={_lastFindings.Count}, " +
                          $"dryRun={_cfg.DryRun}, players={Players.Count()}, bans={_bans.All.Count}, " +
                          $"kick/ban at {_cfg.Scoring.KickAt}/{_cfg.Scoring.BanAt}, vision={(_vision.IsConfigured ? "on" : "off")}, " +
                          $"dashboard={(_dashboard.Enabled ? "on" : "off")}. Commands: /jac reload | panel | dryrun on|off | status | shield install|uninstall|status | scan [list|remove|quarantine|ignore <id>] | integrations [list|suggest|apply|clear] | antidump protect|unprotect <res>|status | audit | info <id> | reset <id>");
                    break;
            }
        }

        private string RunAudit()
        {
            var findings = ServerAudit.Evaluate((name, fallback) => GetConvar(name, fallback));
            foreach (var f in findings) Log("  " + f);
            _dashboard.Enqueue("server_audit", findings.Select(f => (object?)new Dictionary<string, object?>
            {
                ["severity"] = f.Severity, ["convar"] = f.Convar, ["current"] = f.Current, ["recommended"] = f.Recommended, ["why"] = f.Why,
            }).ToList());
            int serious = findings.Count(f => f.Severity == "high" || f.Severity == "medium");
            return findings.Count == 0 ? "server.cfg audit: nothing to change."
                : $"server.cfg audit: {findings.Count} suggestion(s), {serious} high/medium (listed above). Add the 'set' lines to server.cfg and restart.";
        }

        private (int shielded, int withClient) ShieldCoverage()
        {
            int shielded = 0, withClient = 0;
            int n = GetNumResources();
            for (int i = 0; i < n; i++)
            {
                var res = GetResourceByFindIndex(i);
                if (string.IsNullOrEmpty(res) || res == _resource) continue;
                var manifest = LoadResourceFile(res, "fxmanifest.lua");
                if (string.IsNullOrEmpty(manifest)) manifest = LoadResourceFile(res, "__resource.lua");
                if (string.IsNullOrEmpty(manifest) || !ShieldInstaller.HasClientCode(manifest)) continue;
                withClient++;
                if (ShieldInstaller.IsInstalled(manifest)) shielded++;
            }
            return (shielded, withClient);
        }

        private string ShieldCommand(string action)
        {
            int installed = 0, changed = 0, skipped = 0;
            var touched = new List<string>();
            int n = GetNumResources();
            for (int i = 0; i < n; i++)
            {
                var res = GetResourceByFindIndex(i);
                if (string.IsNullOrEmpty(res) || res == _resource || res.StartsWith("_", StringComparison.Ordinal)) continue;
                var file = "fxmanifest.lua";
                var manifest = LoadResourceFile(res, file);
                if (string.IsNullOrEmpty(manifest)) { file = "__resource.lua"; manifest = LoadResourceFile(res, file); }
                if (string.IsNullOrEmpty(manifest)) { skipped++; continue; }
                if (ShieldInstaller.IsInstalled(manifest)) installed++;

                (string text, bool did) result = action == "install" ? ShieldInstaller.Install(manifest)
                    : action == "uninstall" ? ShieldInstaller.Uninstall(manifest) : (manifest, false);
                if (!result.did) continue;
                if (action == "install") SaveResourceFile(res, file + ".jac-backup", manifest, -1);
                SaveResourceFile(res, file, result.text, -1);
                changed++;
                touched.Add(res);
            }
            switch (action)
            {
                case "install":
                    return $"Shield added to {changed} resource(s){(touched.Count > 0 ? ": " + string.Join(", ", touched.Take(30)) : "")}. " +
                           "Run 'refresh' and restart those resources (or the server) to load it.";
                case "uninstall":
                    return $"Shield removed from {changed} resource(s). Run 'refresh' and restart them.";
                default:
                    return $"Shield present in {installed} resource manifest(s); {skipped} without a readable manifest.";
            }
        }

        private void ConfigureFlags()
        {
            _flags.MaxHealth = _cfg.MaxHealth;
            _flags.ExpectedDamageModifier = _cfg.ExpectedDamageModifier;
            _flags.CollisionStreak = (int)_cfg.ServerThresholds["collisionStreakSeconds"];
        }

        private string _lastSuggestions = "";

        private void PushIntegrationSuggestions(bool force)
        {
            var s = _cfg.Integrations.Learning ? _learning.Suggest(_integrations) : new Dictionary<string, List<string>>();
            var payload = new Dictionary<string, object?>
            {
                ["learning"] = _cfg.Integrations.Learning,
                ["suggestions"] = s.OrderBy(kv => kv.Key, StringComparer.OrdinalIgnoreCase)
                    .Select(kv => (object?)new Dictionary<string, object?> { ["resource"] = kv.Key, ["behaviours"] = kv.Value.Cast<object?>().ToList() }).ToList(),
            };
            var json = MiniJson.Serialize(payload);
            if (!force && json == _lastSuggestions) return;
            _lastSuggestions = json;
            _dashboard.Enqueue("integration_suggestions", payload);
        }

        private string IntegrationsCommand(string action, string actor = "console (jac integrations apply)")
        {
            switch (action)
            {
                case "suggest":
                {
                    var s = _learning.Suggest(_integrations);
                    if (!_cfg.Integrations.Learning) return "Learning is off. Turn on integrations.learning, play for a while, then run this again.";
                    if (s.Count == 0) return "No new suggestions yet.";
                    foreach (var kv in s) Log($"  {kv.Key} = {string.Join(", ", kv.Value)}");
                    return $"{s.Count} resource(s) did things they aren't trusted for (listed above). Review them, then 'jac integrations apply'.";
                }
                case "apply":
                {
                    var s = _learning.Suggest(_integrations);
                    if (s.Count == 0) return "Nothing to apply.";
                    var edited = AnticheatConfig.Parse(MiniJson.Serialize(_cfg.ToJson()));
                    foreach (var kv in s)
                    {
                        if (!edited.Integrations.Resources.TryGetValue(kv.Key, out var list)) edited.Integrations.Resources[kv.Key] = list = new List<string>();
                        foreach (var b in kv.Value) if (!list.Contains(b)) list.Add(b);
                    }
                    var applied = Apply(edited, actor, save: true);
                    PushIntegrationSuggestions(true);
                    return applied;
                }
                case "clear":
                    _learning.Clear();
                    PushIntegrationSuggestions(true);
                    return "Learning data cleared.";
                default:
                    foreach (var kv in _integrations.ToClient()) Log($"  {kv.Key} = {string.Join(", ", kv.Value)}");
                    return $"{_integrations.Count} resource rule(s) active (presets for running resources + integrations.resources).";
            }
        }

        private string ReloadFromDisk(string actor)
        {
            var raw = LoadResourceFile(_resource, "config.json");
            if (string.IsNullOrWhiteSpace(raw)) return "config.json is missing or empty; nothing changed.";
            try { return Apply(AnticheatConfig.ParseValidated(raw), actor, save: false); }
            catch (FormatException ex) { return "config.json rejected, nothing changed: " + ex.Message; }
        }

        private string SaveFromJson(string? json, string actor)
        {
            if (string.IsNullOrWhiteSpace(json) || json!.Length > 256 * 1024) return "Empty or oversized settings; nothing changed.";
            try { return Apply(AnticheatConfig.ParseValidated(json), actor, save: true); }
            catch (FormatException ex) { return "Settings rejected, nothing changed: " + ex.Message; }
        }

        private string Apply(AnticheatConfig next, string actor, bool save)
        {
            _cfg.CopyFrom(next);

            _eventRule = new RateLimiter.Rule(_cfg.EventBurst, _cfg.EventRefillPerSecond);
            _weaponBlacklist = new HashSet<uint>(_cfg.WeaponBlacklist.Select(Joaat.Hash));
            _heartbeats.MissingAfter = TimeSpan.FromSeconds(_cfg.HeartbeatMissingSeconds);
            _heartbeats.HandshakeTimeout = TimeSpan.FromSeconds(_cfg.HandshakeTimeoutSeconds);
            _state.MaxHealth = _cfg.MaxHealth;
            ConfigureFlags();
            ApplyServerThresholds();
            RegisterHoneypots();
            RegisterProtectedEvents();
            RebuildIntegrations();

            if (save) SaveResourceFile(_resource, "config.json", _cfg.ToPrettyJson(), -1);

            var payload = MiniJson.Serialize(ClientSettings());
            foreach (var p in Players)
                if (_heartbeats.HasSession(ToId(p.Handle))) p.TriggerEvent(_settingsEvent, payload);

            PushSettingsToDashboard();
            var msg = $"Settings {(save ? "saved and applied" : "reloaded")} by {actor}. dryRun={_cfg.DryRun}.";
            Log(msg);
            _discord.Notice("Settings " + (save ? "saved" : "reloaded"), $"by {actor}; dryRun={_cfg.DryRun}");
            _dashboard.Enqueue("settings_changed", new Dictionary<string, object?> { ["actor"] = actor, ["saved"] = save });
            return msg;
        }

        private Dictionary<string, object?> ClientSettings() => new Dictionary<string, object?>
        {
            ["wb"] = _cfg.WeaponBlacklist, ["mh"] = _cfg.MaxHealth, ["dm"] = _cfg.ExpectedDamageModifier,
            ["ig"] = _cfg.Scoring.Ignore.ToList(), ["iv"] = _cfg.HeartbeatIntervalMs,
            ["mw"] = _cfg.MaxWeapons, ["tb"] = _cfg.TextureBlacklist, ["ct"] = _cfg.ClientThresholds,
            ["cm"] = _cfg.Countermeasures.Enabled, ["cs"] = _cfg.Countermeasures.Skip,
            ["it"] = _integrations.ToClient(), ["ig2"] = _cfg.Integrations.GraceMs, ["il"] = _cfg.Integrations.Learning, ["ita"] = _cfg.Integrations.ClientTrustAllResources,
        };

        private void PushSettingsToDashboard()
        {
            _dashboard.Enqueue("settings", new Dictionary<string, object?>
            {
                ["config"] = _cfg.ToJson(),
                ["schema"] = MiniJson.TryParse(_schemaJson, out var schema) ? schema : null,
            });
        }

        private void OpenPanel(int source, string? result, string? message)
        {
            Players[source]?.TriggerEvent(_panelOpenEvent, MiniJson.Serialize(new Dictionary<string, object?>
            {
                ["schema"] = _schemaJson,
                ["config"] = MiniJson.Serialize(_cfg.ToJson()),
                ["action"] = _panelActionEvent,
                ["result"] = result,
                ["message"] = message,
            }));
        }

        private void OnPanelAction([FromSource] Player player, string action, string json)
        {
            int id = ToId(player.Handle);
            if (!Guard(id, "panel")) return;
            if (!IsAdmin(id))
            {
                Punish(new Violation(id, "NET_HONEYPOT", ViolationSource.Server, new Dictionary<string, object?> { ["event"] = "settings panel" }));
                return;
            }
            string message;
            switch (action)
            {
                case "save": message = SaveFromJson(json, player.Name + " (in game)"); break;
                case "reload": message = ReloadFromDisk(player.Name + " (in game)"); break;
                default: return;
            }
            bool ok = message.StartsWith("Settings", StringComparison.Ordinal);
            OpenPanel(id, ok ? "ok" : "error", message);
        }
    }
}
