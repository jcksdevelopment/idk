using System;
using System.Collections.Concurrent;
using System.Linq;

namespace JcksAnticheat.Core.Validation
{
    public sealed class ScopeTracker
    {
        private readonly ConcurrentDictionary<(int viewer, int player), DateTime> _left = new ConcurrentDictionary<(int, int), DateTime>();
        public TimeSpan Grace { get; set; } = TimeSpan.FromSeconds(3);

        public void Entered(int player, int viewer) => _left.TryRemove((viewer, player), out _);

        public void Left(int player, int viewer, DateTime now) => _left[(viewer, player)] = now;

        public bool KnownOutOfScope(int viewer, int player, DateTime now)
            => _left.TryGetValue((viewer, player), out var at) && now - at > Grace;

        public void Forget(int player)
        {
            foreach (var k in _left.Keys.Where(k => k.viewer == player || k.player == player).ToList()) _left.TryRemove(k, out _);
        }
    }
}
