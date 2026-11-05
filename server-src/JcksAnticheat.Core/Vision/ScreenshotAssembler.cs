using System;
using System.Collections.Concurrent;
using System.Text;

namespace JcksAnticheat.Core.Vision
{
    /// <summary>
    /// Reassembles base64 screenshot chunks sent over latent events. Every capture id is issued by the
    /// server, so chunks for unknown ids (a client pushing unsolicited images) are dropped. Size and
    /// age are capped.
    /// </summary>
    public sealed class ScreenshotAssembler
    {
        private sealed class Capture
        {
            public Capture(int player, string reason, DateTime at) { Player = player; Reason = reason; StartedAt = at; }
            public int Player { get; }
            public string Reason { get; }
            public DateTime StartedAt { get; }
            public string?[]? Parts;
            public int Received;
            public int Bytes;
        }

        public sealed class Completed
        {
            public Completed(string id, int player, string reason, byte[] jpeg) { Id = id; Player = player; Reason = reason; Jpeg = jpeg; }
            public string Id { get; }
            public int Player { get; }
            public string Reason { get; }
            public byte[] Jpeg { get; }
        }

        private readonly ConcurrentDictionary<string, Capture> _captures = new ConcurrentDictionary<string, Capture>(StringComparer.Ordinal);

        public int MaxBase64Bytes { get; set; } = 4 * 1024 * 1024;
        public int MaxChunks { get; set; } = 256;
        public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);

        public string Begin(int player, string reason, DateTime? now = null)
        {
            var id = Guid.NewGuid().ToString("N");
            _captures[id] = new Capture(player, reason, now ?? DateTime.UtcNow);
            return id;
        }

        public bool IsPending(int player)
        {
            foreach (var c in _captures.Values) if (c.Player == player) return true;
            return false;
        }

        public enum ChunkResult { Accepted, Complete, Unknown, Rejected, Unavailable }

        public ChunkResult AddChunk(int player, string? id, int index, int total, string? data, out Completed? completed)
        {
            completed = null;
            if (id == null || !_captures.TryGetValue(id, out var cap) || cap.Player != player) return ChunkResult.Unknown;

            if (total == 0 && data == "unavailable")
            {
                _captures.TryRemove(id, out _);
                return ChunkResult.Unavailable;
            }

            lock (cap)
            {
                if (total <= 0 || total > MaxChunks || index < 1 || index > total || data == null)
                {
                    _captures.TryRemove(id, out _);
                    return ChunkResult.Rejected;
                }
                if (cap.Parts == null) cap.Parts = new string?[total];
                else if (cap.Parts.Length != total) { _captures.TryRemove(id, out _); return ChunkResult.Rejected; }

                if (cap.Parts[index - 1] != null) return ChunkResult.Accepted; // duplicate, ignore
                cap.Bytes += data.Length;
                if (cap.Bytes > MaxBase64Bytes) { _captures.TryRemove(id, out _); return ChunkResult.Rejected; }

                cap.Parts[index - 1] = data;
                cap.Received++;
                if (cap.Received < total) return ChunkResult.Accepted;

                _captures.TryRemove(id, out _);
                var sb = new StringBuilder(cap.Bytes);
                foreach (var p in cap.Parts) sb.Append(p);
                byte[] jpeg;
                try { jpeg = Convert.FromBase64String(sb.ToString()); }
                catch (FormatException) { return ChunkResult.Rejected; }
                completed = new Completed(id, player, cap.Reason, jpeg);
                return ChunkResult.Complete;
            }
        }

        public void Sweep(DateTime? now = null)
        {
            var t = now ?? DateTime.UtcNow;
            foreach (var kv in _captures)
                if (t - kv.Value.StartedAt > Timeout) _captures.TryRemove(kv.Key, out _);
        }
    }
}
