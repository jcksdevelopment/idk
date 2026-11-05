using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Logging
{
    public sealed class StaffAlertConfig
    {
        public bool Enabled { get; set; } = true;
        public string MinAction { get; set; } = "log";
        public int CooldownSeconds { get; set; } = 30;
    }

    public sealed class StaffAlerts
    {
        private readonly StaffAlertConfig _config;
        private readonly ConcurrentDictionary<string, DateTime> _last = new ConcurrentDictionary<string, DateTime>(StringComparer.Ordinal);

        public StaffAlerts(StaffAlertConfig config) { _config = config; }

        public string? Message(string playerName, Violation v, bool bypass, bool dryRun, DateTime now)
        {
            if (!_config.Enabled || bypass) return null;
            if (DiscordWebhook.Rank(v.Action) < DiscordWebhook.Rank(_config.MinAction)) return null;
            var key = v.Player + ":" + v.Code;
            if (v.Action != EnforcementAction.Kick && v.Action != EnforcementAction.Ban
                && _last.TryGetValue(key, out var t) && now - t < TimeSpan.FromSeconds(_config.CooldownSeconds)) return null;
            _last[key] = now;
            var action = v.Action == EnforcementAction.None ? "log" : v.Action.ToString().ToLowerInvariant();
            return $"{playerName} (#{v.Player}) {v.Code} +{v.Severity} = {v.ScoreAfter:F0} [{action}{(dryRun ? ", dry run" : "")}]";
        }

        public void Forget(int player)
        {
            foreach (var k in _last.Keys.Where(k => k.StartsWith(player + ":", StringComparison.Ordinal)).ToList()) _last.TryRemove(k, out _);
        }
    }

    public sealed class RecentViolations
    {
        private readonly ConcurrentDictionary<int, List<(DateTime at, string code, int severity)>> _items = new ConcurrentDictionary<int, List<(DateTime, string, int)>>();
        private readonly int _keep;

        public RecentViolations(int keep = 10) { _keep = keep; }

        public void Add(Violation v)
        {
            var list = _items.GetOrAdd(v.Player, _ => new List<(DateTime, string, int)>());
            lock (list)
            {
                list.Add((v.At, v.Code, v.Severity));
                if (list.Count > _keep) list.RemoveAt(0);
            }
        }

        public List<(DateTime at, string code, int severity)> Of(int player)
        {
            if (!_items.TryGetValue(player, out var list)) return new List<(DateTime, string, int)>();
            lock (list) return list.ToList();
        }

        public void Forget(int player) => _items.TryRemove(player, out _);
    }
}
