using System;
using System.Collections.Generic;
using System.Linq;

namespace JcksAnticheat.Core.Detection
{
    public sealed class GraceDeferral
    {
        public sealed class Item
        {
            public int Player;
            public string Kind = "";
            public DateTime DetectedAt;
            public DateTime DueAt;
            public Violation? Violation;
            public Action? Countermeasure;
        }

        public static readonly TimeSpan Window = TimeSpan.FromSeconds(2.5);
        private readonly List<Item> _items = new List<Item>();
        private readonly Dictionary<string, DateTime> _grants = new Dictionary<string, DateTime>(StringComparer.Ordinal);

        public int Pending => _items.Count;

        public static string? KindFor(string code)
        {
            switch (code)
            {
                case "MOV_TELEPORT":
                case "PLY_SPEED_FOOT":
                case "MOV_SPEED_VEH":
                case "MOV_NOCLIP_ZVEL":
                    return "teleport";
                case "PLY_HEALTH_REGEN":
                case "PLY_HEALTH_CAP":
                    return "heal";
                case "PLY_ARMOR_REGEN":
                    return "armor";
                case "PLY_GODMODE_FLAG":
                case "PLY_GODMODE_PROOFS":
                    return "godmode";
                case "MOV_NOCLIP_COLLISION":
                    return "noclip";
                case "WPN_DMG_MODIFIER":
                    return "weapons";
                case "PLY_INVISIBLE":
                    return "invisible";
                case "PLY_SUPERJUMP":
                    return "superjump";
                default:
                    return null;
            }
        }

        public void RecordGrant(int player, string kind, DateTime at) => _grants[player + ":" + kind] = at;

        public void Add(int player, string kind, DateTime now, Violation? violation, Action? countermeasure)
            => _items.Add(new Item { Player = player, Kind = kind, DetectedAt = now, DueAt = now + Window, Violation = violation, Countermeasure = countermeasure });

        public bool GrantedAround(int player, string kind, DateTime at)
        {
            var kinds = kind == "teleport" ? new[] { "teleport", "noclip" } : new[] { kind };
            foreach (var k in kinds)
                if (_grants.TryGetValue(player + ":" + k, out var t) && t >= at - Window - TimeSpan.FromSeconds(1)) return true;
            return false;
        }

        public List<Item> Resolve(DateTime now, Func<int, bool> online)
        {
            var confirmed = new List<Item>();
            foreach (var d in _items.Where(x => x.DueAt <= now).ToList())
            {
                _items.Remove(d);
                if (!GrantedAround(d.Player, d.Kind, d.DetectedAt) && online(d.Player)) confirmed.Add(d);
            }
            return confirmed;
        }

        public void Forget(int player)
        {
            _items.RemoveAll(d => d.Player == player);
            foreach (var k in _grants.Keys.Where(k => k.StartsWith(player + ":", StringComparison.Ordinal)).ToList()) _grants.Remove(k);
        }
    }
}
