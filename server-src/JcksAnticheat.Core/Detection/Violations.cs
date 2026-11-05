using System;
using System.Collections.Concurrent;
using System.Collections.Generic;

namespace JcksAnticheat.Core.Detection
{
    public enum ViolationSource { Client, Server, Heartbeat, Vision }

    public enum EnforcementAction { None, Log, Screenshot, Kick, Ban }

    public sealed class Violation
    {
        public Violation(int player, string code, ViolationSource source, IDictionary<string, object?>? evidence = null)
        {
            Player = player;
            Code = code;
            Source = source;
            Evidence = evidence ?? new Dictionary<string, object?>();
            At = DateTime.UtcNow;
        }

        public int Player { get; }
        public string Code { get; }
        public ViolationSource Source { get; }
        public IDictionary<string, object?> Evidence { get; }
        public DateTime At { get; }
        public int Severity { get; internal set; }
        public double ScoreAfter { get; internal set; }
        public EnforcementAction Action { get; internal set; }

        public override string ToString() => $"[{Code}] player={Player} sev={Severity} score={ScoreAfter:F0} action={Action}";
    }

    public static class ViolationCatalog
    {
        public static readonly IReadOnlyDictionary<string, int> DefaultSeverity = new Dictionary<string, int>(StringComparer.Ordinal)
        {
            ["PLY_GODMODE_FLAG"] = 40, ["PLY_GODMODE_PROOFS"] = 35, ["PLY_HEALTH_REGEN"] = 25,
            ["PLY_ARMOR_REGEN"] = 25, ["PLY_HEALTH_CAP"] = 30, ["PLY_DAMAGE_ABSORB"] = 30,
            ["PLY_NO_RAGDOLL"] = 15, ["PLY_SUPERJUMP"] = 30, ["PLY_SPEED_FOOT"] = 30,
            ["PLY_STAMINA"] = 10, ["PLY_VISION"] = 15, ["PLY_INVISIBLE"] = 30, ["PLY_PED_MODEL"] = 20, ["PLY_SPECTATE"] = 35, ["PLY_TINY_PED"] = 30, ["PLY_SELF_REVIVE"] = 35, ["WPN_GIVE_ALL"] = 40,

            ["MOV_FREECAM"] = 25, ["MOV_NOCLIP_COLLISION"] = 40, ["MOV_NOCLIP_FLOAT"] = 35,
            ["MOV_NOCLIP_ZVEL"] = 35, ["MOV_TELEPORT"] = 40, ["MOV_BRING_ALL"] = 50, ["MOV_SPEED_VEH"] = 30,

            ["WPN_BLACKLIST"] = 50, ["WPN_GIVE_EVENT"] = 50, ["WPN_DMG_MODIFIER"] = 40, ["WPN_RANGE"] = 25,
            ["WPN_AIM_ANGLE"] = 30, ["WPN_TRAJECTORY"] = 20, ["WPN_AIM_SNAP"] = 20, ["WPN_HEADSHOT_RATIO"] = 30, ["WPN_TRIGGERBOT"] = 15,
            ["WPN_RAPID_FIRE"] = 30, ["WPN_INFINITE_AMMO"] = 20, ["WPN_EXPLOSIVE_AMMO"] = 50,
            ["WPN_EXPLOSION_BLACKLIST"] = 50, ["WPN_EXPLOSION_BLAME"] = 35,
            ["WPN_PROJECTILE_ORIGIN"] = 45, ["WPN_PROJECTILE_SPAM"] = 40, ["WPN_FIRE_PLAYER"] = 45, ["WPN_FIRE_SPAM"] = 40,
            ["NET_PTFX_SPAM"] = 35,

            ["VEH_SPAWN"] = 40, ["ENT_SPAWN_FLOOD"] = 45, ["VEH_HANDLING"] = 30, ["VEH_POWER"] = 30, ["VEH_GODMODE"] = 30, ["VEH_REPAIR"] = 25, ["VEH_HIJACK"] = 40, ["VEH_RAINBOW"] = 20, ["VEH_PLATE"] = 20, ["EXE_MENU_TEXTURE"] = 50,

            ["NET_RATE"] = 20, ["NET_FLOOD"] = 40, ["NET_HONEYPOT"] = 60, ["NET_CLEAR_TASKS"] = 40, ["NET_EVENT_SPAM"] = 30, ["NET_CHAT_SPOOF"] = 40, ["HB_MISSING"] = 60, ["HB_INVALID"] = 60, ["HB_STATE_MISMATCH"] = 30,
            ["EXE_RESOURCE_COUNT"] = 40, ["EXE_RESOURCE_INJECT"] = 50, ["EXE_COMMAND_INJECT"] = 40,
            ["EXE_GLOBAL_TAMPER"] = 50, ["EXE_LUA_INJECT"] = 60, ["EXE_SHIELD_TAMPER"] = 60, ["NUI_DEVTOOLS"] = 40, ["NUI_FRAME_INJECT"] = 40,
            ["CHK_ERROR"] = 5,

            ["VIS_AI_FLAG"] = 0,
        };
    }

    public sealed class ScoringPolicy
    {
        public double ScreenshotAt { get; set; } = 40;
        public double KickAt { get; set; } = 80;
        public double BanAt { get; set; } = 140;
        public double HalfLifeMinutes { get; set; } = 10;
        public Dictionary<string, int> SeverityOverrides { get; set; } = new Dictionary<string, int>(StringComparer.Ordinal);
        public HashSet<string> Ignore { get; set; } = new HashSet<string>(StringComparer.Ordinal);
        public HashSet<string> LogOnly { get; set; } = new HashSet<string>(StringComparer.Ordinal);
        public HashSet<string> DropImmediately { get; set; } = new HashSet<string>(StringComparer.Ordinal) { "HB_INVALID", "HB_MISSING", "NET_FLOOD" };
        public HashSet<string> AlwaysBan { get; set; } = new HashSet<string>(StringComparer.Ordinal);
    }

    public sealed class ViolationLedger
    {
        private sealed class Entry
        {
            public double Score;
            public DateTime UpdatedAt = DateTime.UtcNow;
            public bool HasServerSignal;
        }

        private readonly ConcurrentDictionary<int, Entry> _entries = new ConcurrentDictionary<int, Entry>();
        private readonly ScoringPolicy _policy;

        public ViolationLedger(ScoringPolicy policy) { _policy = policy; }

        public int SeverityOf(string code)
        {
            if (_policy.SeverityOverrides.TryGetValue(code, out var o)) return o;
            return ViolationCatalog.DefaultSeverity.TryGetValue(code, out var s) ? s : 10;
        }

        public double ScoreOf(int player, DateTime? now = null)
        {
            if (!_entries.TryGetValue(player, out var e)) return 0;
            lock (e) return Decay(e, now ?? DateTime.UtcNow);
        }

        public void Record(Violation v, DateTime? now = null)
        {
            var t = now ?? v.At;
            var entry = _entries.GetOrAdd(v.Player, _ => new Entry());
            lock (entry)
            {
                double score = Decay(entry, t);
                v.Severity = SeverityOf(v.Code);
                score += v.Severity;
                if (v.Source != ViolationSource.Client) entry.HasServerSignal = true;

                if (!entry.HasServerSignal && score >= _policy.BanAt)
                {
                    score = Math.Max(_policy.KickAt, _policy.BanAt - 1);
                }

                entry.Score = score;
                entry.UpdatedAt = t;
                v.ScoreAfter = score;

                if (_policy.LogOnly.Contains(v.Code)) v.Action = EnforcementAction.Log;
                else if (score >= _policy.BanAt || _policy.AlwaysBan.Contains(v.Code)) v.Action = EnforcementAction.Ban;
                else if (score >= _policy.KickAt || _policy.DropImmediately.Contains(v.Code)) v.Action = EnforcementAction.Kick;
                else if (score >= _policy.ScreenshotAt) v.Action = EnforcementAction.Screenshot;
                else v.Action = EnforcementAction.Log;
            }
        }

        public void Forget(int player) => _entries.TryRemove(player, out _);

        private readonly ConcurrentDictionary<string, Entry> _parked = new ConcurrentDictionary<string, Entry>(StringComparer.Ordinal);

        public void Park(int player, string? key, DateTime? now = null)
        {
            if (!_entries.TryRemove(player, out var e) || string.IsNullOrEmpty(key)) return;
            lock (e)
            {
                if (Decay(e, now ?? DateTime.UtcNow) < 1) return;
            }
            _parked[key!] = e;
            if (_parked.Count > 10000) Prune(now ?? DateTime.UtcNow);
        }

        public void Restore(int player, string? key, DateTime? now = null)
        {
            if (string.IsNullOrEmpty(key) || !_parked.TryRemove(key!, out var e)) return;
            lock (e)
            {
                if (Decay(e, now ?? DateTime.UtcNow) < 1) return;
            }
            _entries[player] = e;
        }

        public int ParkedCount => _parked.Count;

        private void Prune(DateTime now)
        {
            foreach (var kv in _parked)
                lock (kv.Value)
                    if (Decay(kv.Value, now) < 1) _parked.TryRemove(kv.Key, out _);
        }

        private double Decay(Entry e, DateTime now)
        {
            var minutes = (now - e.UpdatedAt).TotalMinutes;
            if (minutes <= 0) return e.Score;
            var score = e.Score * Math.Pow(0.5, minutes / _policy.HalfLifeMinutes);
            e.Score = score;
            e.UpdatedAt = now;
            return score;
        }
    }
}
