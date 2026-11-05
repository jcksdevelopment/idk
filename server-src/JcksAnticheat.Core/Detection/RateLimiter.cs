using System;
using System.Collections.Concurrent;
using System.Diagnostics;

namespace JcksAnticheat.Core.Detection
{
    public sealed class RateLimiter
    {
        public readonly struct Key : IEquatable<Key>
        {
            public Key(int player, string bucket) { Player = player; Bucket = bucket; }
            public int Player { get; }
            public string Bucket { get; }
            public bool Equals(Key other) => Player == other.Player && string.Equals(Bucket, other.Bucket, StringComparison.Ordinal);
            public override bool Equals(object? obj) => obj is Key k && Equals(k);
            public override int GetHashCode() => unchecked(Player * 397 ^ (Bucket?.GetHashCode() ?? 0));
        }

        private sealed class Bucket
        {
            public double Tokens;
            public long LastTicks;
        }

        public sealed class Rule
        {
            public Rule(double capacity, double refillPerSecond) { Capacity = capacity; RefillPerSecond = refillPerSecond; }
            public double Capacity { get; }
            public double RefillPerSecond { get; }
        }

        private readonly ConcurrentDictionary<Key, Bucket> _buckets = new ConcurrentDictionary<Key, Bucket>();
        private readonly Func<long> _clock;
        private static readonly double TicksPerSecond = Stopwatch.Frequency;

        public RateLimiter(Func<long>? clock = null)
        {
            _clock = clock ?? Stopwatch.GetTimestamp;
        }

        public bool TryConsume(int player, string bucket, Rule rule, double cost = 1)
        {
            long now = _clock();
            var b = _buckets.GetOrAdd(new Key(player, bucket), _ => new Bucket { Tokens = rule.Capacity, LastTicks = now });
            lock (b)
            {
                double elapsed = (now - b.LastTicks) / TicksPerSecond;
                if (elapsed > 0)
                {
                    b.Tokens = Math.Min(rule.Capacity, b.Tokens + elapsed * rule.RefillPerSecond);
                    b.LastTicks = now;
                }
                if (b.Tokens < cost) return false;
                b.Tokens -= cost;
                return true;
            }
        }

        public void ForgetPlayer(int player)
        {
            foreach (var key in _buckets.Keys)
                if (key.Player == player) _buckets.TryRemove(key, out _);
        }

        public int Count => _buckets.Count;
    }

    public sealed class SlidingCounter
    {
        private readonly ConcurrentDictionary<string, ConcurrentQueue<DateTime>> _events =
            new ConcurrentDictionary<string, ConcurrentQueue<DateTime>>(StringComparer.Ordinal);

        public int Add(string key, DateTime now, TimeSpan window)
        {
            var q = _events.GetOrAdd(key, _ => new ConcurrentQueue<DateTime>());
            q.Enqueue(now);
            var cutoff = now - window;
            while (q.TryPeek(out var head) && head < cutoff) q.TryDequeue(out _);
            return q.Count;
        }

        public void RemoveWhere(Func<string, bool> predicate)
        {
            foreach (var k in _events.Keys)
                if (predicate(k)) _events.TryRemove(k, out _);
        }
    }
}
