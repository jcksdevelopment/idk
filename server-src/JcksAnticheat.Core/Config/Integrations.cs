using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Config
{
    public sealed class IntegrationsConfig
    {
        /// <summary>Merge integrations.presets.json for resources that exist on this server.</summary>
        public bool UsePresets { get; set; } = true;
        /// <summary>Record which resources do what, so 'jac integrations suggest' can propose rules.</summary>
        public bool Learning { get; set; }
        public int GraceMs { get; set; } = 5000;
        /// <summary>resource → behaviours it may trigger (heal, armor, godmode, teleport, invisible, noclip, spectate, vehicle, weapons, camera, ragdoll, or *).</summary>
        public Dictionary<string, List<string>> Resources { get; set; } = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
    }

    public static class Behaviours
    {
        public static readonly string[] All = { "heal", "armor", "godmode", "teleport", "invisible", "noclip", "spectate", "vehicle", "weapons", "camera", "ragdoll" };
        public static bool IsKnown(string b) => b == "*" || All.Contains(b);
    }

    /// <summary>Effective resource → behaviour rules: presets for running resources, then the server's own rules on top.</summary>
    public sealed class IntegrationPolicy
    {
        private readonly Dictionary<string, HashSet<string>> _rules = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);

        public static IntegrationPolicy Build(IntegrationsConfig config, IReadOnlyDictionary<string, List<string>>? presets, Func<string, bool> resourceExists)
        {
            var p = new IntegrationPolicy();
            if (config.UsePresets && presets != null)
                foreach (var kv in presets)
                    if (resourceExists(kv.Key)) p.Set(kv.Key, kv.Value);
            foreach (var kv in config.Resources) p.Set(kv.Key, kv.Value);
            return p;
        }

        private void Set(string resource, IEnumerable<string> behaviours)
            => _rules[resource] = new HashSet<string>(behaviours.Where(Behaviours.IsKnown), StringComparer.Ordinal);

        public bool Allows(string resource, string behaviour)
            => _rules.TryGetValue(resource, out var set) && (set.Contains(behaviour) || set.Contains("*"));

        public Dictionary<string, List<string>> ToClient() => _rules.ToDictionary(k => k.Key, k => k.Value.OrderBy(x => x).ToList(), StringComparer.OrdinalIgnoreCase);

        public int Count => _rules.Count;

        public static Dictionary<string, List<string>> ParsePresets(string? json)
        {
            var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            if (string.IsNullOrWhiteSpace(json) || !MiniJson.TryParse(json!, out var root) || !(root.Obj("resources") is { } res)) return result;
            foreach (var kv in res)
                if (kv.Value is List<object?> list) result[kv.Key] = list.OfType<string>().ToList();
            return result;
        }
    }

    /// <summary>Learning mode: counts behaviour per resource (allowed or not) across players.</summary>
    public sealed class IntegrationLearning
    {
        private readonly ConcurrentDictionary<string, int> _counts = new ConcurrentDictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        public void Record(string resource, string behaviour)
        {
            if (string.IsNullOrEmpty(resource) || !Behaviours.IsKnown(behaviour) || resource.Length > 64) return;
            _counts.AddOrUpdate(resource + "|" + behaviour, 1, (_, n) => n + 1);
        }

        /// <summary>Behaviours seen at least minCount times that the policy doesn't allow yet.</summary>
        public Dictionary<string, List<string>> Suggest(IntegrationPolicy policy, int minCount = 3)
        {
            var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var kv in _counts.Where(k => k.Value >= minCount))
            {
                var parts = kv.Key.Split('|');
                if (policy.Allows(parts[0], parts[1])) continue;
                if (!result.TryGetValue(parts[0], out var list)) result[parts[0]] = list = new List<string>();
                list.Add(parts[1]);
            }
            foreach (var l in result.Values) l.Sort(StringComparer.Ordinal);
            return result;
        }

        public void Clear() => _counts.Clear();
    }
}
