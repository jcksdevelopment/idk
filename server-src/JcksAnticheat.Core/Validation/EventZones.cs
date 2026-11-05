using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace JcksAnticheat.Core.Validation
{
    public readonly struct EventZone
    {
        public EventZone(Vec3 center, float radius) { Center = center; Radius = radius; }
        public Vec3 Center { get; }
        public float Radius { get; }
    }

    public static class EventZones
    {
        public static bool TryCompile(IReadOnlyList<string> values, out List<EventZone> zones)
        {
            zones = new List<EventZone>();
            if (values.Count == 0 || values.Count % 4 != 0) return false;
            var n = new float[values.Count];
            for (int i = 0; i < values.Count; i++)
                if (!float.TryParse(values[i], NumberStyles.Float, CultureInfo.InvariantCulture, out n[i])) return false;
            for (int i = 0; i < n.Length; i += 4)
            {
                if (n[i + 3] <= 0 || n[i + 3] > 20000) return false;
                zones.Add(new EventZone(new Vec3(n[i], n[i + 1], n[i + 2]), n[i + 3]));
            }
            return true;
        }

        public static Dictionary<string, List<EventZone>> Compile(Dictionary<string, List<string>> config)
        {
            var result = new Dictionary<string, List<EventZone>>(StringComparer.Ordinal);
            foreach (var kv in config)
                if (TryCompile(kv.Value, out var zones)) result[kv.Key] = zones;
            return result;
        }

        public static bool Inside(IEnumerable<EventZone> zones, Vec3 position, out float nearest)
        {
            nearest = float.MaxValue;
            foreach (var z in zones)
            {
                float d = (position - z.Center).Length;
                if (d <= z.Radius) { nearest = d; return true; }
                nearest = Math.Min(nearest, d - z.Radius);
            }
            return false;
        }
    }
}
