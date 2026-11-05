using System;
using System.Collections.Concurrent;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Logging
{
    public sealed class ReportThrottle
    {
        private sealed class Entry
        {
            public DateTime At;
            public EnforcementAction Action;
            public int Suppressed;
        }

        private readonly ConcurrentDictionary<string, Entry> _last = new ConcurrentDictionary<string, Entry>(StringComparer.Ordinal);
        public TimeSpan Window { get; set; } = TimeSpan.FromSeconds(3);

        public bool ShouldReport(Violation v, DateTime now, out int suppressed)
        {
            suppressed = 0;
            var key = v.Player + ":" + v.Code;
            var e = _last.GetOrAdd(key, _ => new Entry { At = DateTime.MinValue });
            lock (e)
            {
                if (now - e.At < Window && v.Action <= e.Action)
                {
                    e.Suppressed++;
                    return false;
                }
                suppressed = e.Suppressed;
                e.Suppressed = 0;
                e.At = now;
                e.Action = v.Action;
                return true;
            }
        }

        public void Forget(int player)
        {
            foreach (var k in _last.Keys)
                if (k.StartsWith(player + ":", StringComparison.Ordinal)) _last.TryRemove(k, out _);
        }
    }
}
