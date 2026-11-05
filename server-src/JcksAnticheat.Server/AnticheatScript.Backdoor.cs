using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JcksAnticheat.Core.Backdoor;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private readonly ConcurrentQueue<List<Finding>> _scanResults = new ConcurrentQueue<List<Finding>>();
        private List<Finding> _lastFindings = new List<Finding>();
        private readonly Dictionary<string, string> _resourceRoots = new Dictionary<string, string>(StringComparer.Ordinal);
        private int _scanning;

        private static Severity ParseSeverity(string s) => s == "high" ? Severity.High : s == "low" ? Severity.Low : Severity.Medium;

        private string StartBackdoorScan(string reason)
        {
            if (!_cfg.Backdoor.Enabled) return "Backdoor scanner is disabled (backdoorScanner.enabled).";
            if (System.Threading.Interlocked.Exchange(ref _scanning, 1) == 1) return "A scan is already running.";

            var targets = new List<(string name, string root)>();
            int n = GetNumResources();
            for (int i = 0; i < n; i++)
            {
                var name = GetResourceByFindIndex(i);
                if (string.IsNullOrEmpty(name) || name == _resource) continue;
                var root = GetResourcePath(name);
                if (string.IsNullOrEmpty(root)) continue;
                targets.Add((name, root));
                _resourceRoots[name] = root;
            }

            var options = new ScanOptions
            {
                IgnoreIds = new HashSet<string>(_cfg.Backdoor.IgnoreIds, StringComparer.Ordinal),
                IgnoreResources = new HashSet<string>(_cfg.Backdoor.IgnoreResources, StringComparer.OrdinalIgnoreCase),
                DisabledRules = new HashSet<string>(_cfg.Backdoor.DisabledRules, StringComparer.Ordinal),
            };
            Log($"backdoor scan started ({reason}): {targets.Count} resources");
            Task.Run(() =>
            {
                var all = new List<Finding>();
                try
                {
                    foreach (var (name, root) in targets) all.AddRange(BackdoorScanner.ScanResource(name, root, options));
                }
                catch (Exception ex) { Log("backdoor scan error: " + ex.Message); }
                _scanResults.Enqueue(all);
            });
            return $"Scanning {targets.Count} resources…";
        }

        private void DrainBackdoorResults()
        {
            while (_scanResults.TryDequeue(out var findings))
            {
                System.Threading.Interlocked.Exchange(ref _scanning, 0);
                var min = ParseSeverity(_cfg.Backdoor.MinSeverity);
                _lastFindings = findings.Where(f => f.Severity >= min).OrderByDescending(f => f.Severity).ThenBy(f => f.Resource).ToList();
                ReportFindings();
                ApplyAutoAction();
                _dashboard.Enqueue("backdoor_scan", _lastFindings.Select(f => new Dictionary<string, object?>
                {
                    ["id"] = f.Id, ["resource"] = f.Resource, ["file"] = f.File, ["line"] = f.Line, ["rule"] = f.Rule,
                    ["severity"] = f.Severity.ToString().ToLowerInvariant(), ["description"] = f.Description, ["snippet"] = f.Snippet,
                }).ToList());
                if (_lastFindings.Any(f => f.Severity == Severity.High))
                    _discord.Notice("Backdoor scan", $"{_lastFindings.Count(f => f.Severity == Severity.High)} high-severity finding(s). Run `jac scan` in the server console.");
            }
        }

        private void ReportFindings()
        {
            if (_lastFindings.Count == 0) { Log("backdoor scan: no findings"); return; }
            Log($"backdoor scan: {_lastFindings.Count} finding(s)");
            foreach (var f in _lastFindings)
            {
                Log($"  [{f.Severity.ToString().ToUpperInvariant()}] {f.Id}  {f.Resource}/{f.File}:{f.Line}  {f.Rule}: {f.Description}");
                Log($"      > {f.Snippet}");
            }
            Log("  review each one, then: jac scan remove <id> | jac scan quarantine <id> | jac scan ignore <id>");
        }

        private void ApplyAutoAction()
        {
            var action = _cfg.Backdoor.AutoAction;
            if (action == "none") return;
            var min = ParseSeverity(_cfg.Backdoor.AutoActionMinSeverity);
            foreach (var f in _lastFindings.Where(f => f.Severity >= min).ToList())
                Log("  auto " + action + ": " + ActOnFinding(f, action));
        }

        private string ActOnFinding(Finding f, string action)
        {
            string message;
            bool ok = action == "quarantine"
                ? BackdoorRemover.Quarantine(f, _resourceRoots.TryGetValue(f.Resource, out var root) ? root : GetResourcePath(f.Resource), out message)
                : BackdoorRemover.RemoveLine(f, out message);
            if (ok) _lastFindings.Remove(f);
            return (ok ? "" : "failed: ") + message;
        }

        private string BackdoorCommand(List<object> args)
        {
            var sub = args.Count > 1 ? args[1]?.ToString() ?? "" : "";
            var id = args.Count > 2 ? args[2]?.ToString() ?? "" : "";
            if (sub == "" ) return StartBackdoorScan("manual");
            if (sub == "list") { ReportFindings(); return $"{_lastFindings.Count} finding(s) listed above."; }
            var f = _lastFindings.FirstOrDefault(x => x.Id == id);
            if (f == null) return $"No finding with id '{id}'. Run 'jac scan' or 'jac scan list'.";
            switch (sub)
            {
                case "remove": return ActOnFinding(f, "remove") + ". Restart the resource to load the change.";
                case "quarantine": return ActOnFinding(f, "quarantine") + ".";
                case "ignore":
                    var edited = JcksAnticheat.Core.Config.AnticheatConfig.Parse(JcksAnticheat.Core.Json.MiniJson.Serialize(_cfg.ToJson()));
                    if (!edited.Backdoor.IgnoreIds.Contains(id)) edited.Backdoor.IgnoreIds.Add(id);
                    _lastFindings.Remove(f);
                    return Apply(edited, "console (jac scan ignore)", save: true);
                default: return "Usage: jac scan [list | remove <id> | quarantine <id> | ignore <id>]";
            }
        }
    }
}
