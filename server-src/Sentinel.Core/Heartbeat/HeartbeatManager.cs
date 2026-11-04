using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Text;
using Sentinel.Core.Crypto;
using Sentinel.Core.Json;

namespace Sentinel.Core.Heartbeat
{
    public enum HeartbeatStatus { Ok, NoSession, Malformed, BadMac, Replay, BadChallenge, BadPayload }

    public sealed class HeartbeatResult
    {
        public HeartbeatStatus Status { get; set; }
        public string? Reason { get; set; }
        /// <summary>Decrypted payload: { s, c, t, f: [ {c, t, d} ], st: {...} }.</summary>
        public Dictionary<string, object?>? Payload { get; set; }
        /// <summary>Challenge to send back to the client for its next heartbeat.</summary>
        public string? NextChallenge { get; set; }
        public bool Ok => Status == HeartbeatStatus.Ok;
    }

    public sealed class HeartbeatSession
    {
        internal HeartbeatSession(int player, byte[] key, string challenge, DateTime now)
        {
            Player = player;
            Key = key;
            Challenge = challenge;
            CreatedAt = now;
            LastValidAt = now;
        }

        public int Player { get; }
        internal byte[] Key;
        internal uint Seq;
        internal string Challenge;
        internal string? PreviousChallenge;
        public DateTime CreatedAt { get; }
        public DateTime LastValidAt { get; internal set; }
        public int Failures { get; internal set; }
        public bool MissingReported { get; internal set; }
        public uint Sequence => Seq;
    }

    /// <summary>
    /// Owns every player's heartbeat session. Wire format (all hex): seq, nonce(16B), ciphertext, mac.
    /// mac = HMAC(key, uint32_be(seq) || nonce || ciphertext); plaintext = CTR(key, nonce, ciphertext).
    /// After a valid packet both sides ratchet key = SHA256(key || mac).
    /// </summary>
    public sealed class HeartbeatManager
    {
        private readonly ConcurrentDictionary<int, HeartbeatSession> _sessions = new ConcurrentDictionary<int, HeartbeatSession>();

        public TimeSpan MissingAfter { get; set; } = TimeSpan.FromSeconds(20);
        /// <summary>The first heartbeat is allowed to take longer (client still loading).</summary>
        public TimeSpan FirstHeartbeatGrace { get; set; } = TimeSpan.FromSeconds(90);
        public int MaxCiphertextBytes { get; set; } = 8 * 1024;

        /// <summary>Starts (or restarts) a session. Returns the hex key and first challenge to send to the client.</summary>
        public (string keyHex, string challenge) Begin(int player, DateTime? now = null)
        {
            var key = SentinelCrypto.RandomBytes(32);
            var challenge = NewChallenge();
            _sessions[player] = new HeartbeatSession(player, key, challenge, now ?? DateTime.UtcNow);
            return (SentinelCrypto.ToHex(key), challenge);
        }

        public bool HasSession(int player) => _sessions.ContainsKey(player);

        public HeartbeatSession? Get(int player) => _sessions.TryGetValue(player, out var s) ? s : null;

        public void End(int player) => _sessions.TryRemove(player, out _);

        public HeartbeatResult Verify(int player, object? seqArg, string? nonceHex, string? ctHex, string? macHex, DateTime? now = null)
        {
            if (!_sessions.TryGetValue(player, out var session))
                return new HeartbeatResult { Status = HeartbeatStatus.NoSession, Reason = "no session" };

            lock (session)
            {
                var t = now ?? DateTime.UtcNow;
                uint seq;
                try { seq = Convert.ToUInt32(seqArg); }
                catch { return Fail(session, HeartbeatStatus.Malformed, "seq"); }

                var nonce = SentinelCrypto.FromHex(nonceHex, 16);
                var ct = SentinelCrypto.FromHex(ctHex, MaxCiphertextBytes);
                var mac = SentinelCrypto.FromHex(macHex, 32);
                if (nonce == null || nonce.Length != 16 || ct == null || mac == null || mac.Length != 32)
                    return Fail(session, HeartbeatStatus.Malformed, "encoding");

                if (seq != session.Seq + 1)
                    return Fail(session, HeartbeatStatus.Replay, $"seq {seq} expected {session.Seq + 1}");

                var expected = SentinelCrypto.Hmac(session.Key, SentinelCrypto.Concat(SentinelCrypto.UInt32BE(seq), nonce, ct));
                if (!SentinelCrypto.FixedTimeEquals(expected, mac))
                    return Fail(session, HeartbeatStatus.BadMac, "mac mismatch");

                var plain = Encoding.UTF8.GetString(SentinelCrypto.Ctr(session.Key, nonce, ct));
                if (!MiniJson.TryParse(plain, out var parsed, MaxCiphertextBytes) || !(parsed is Dictionary<string, object?> payload))
                    return Fail(session, HeartbeatStatus.BadPayload, "json");

                if (payload.Num("s") is not double ps || (uint)ps != seq)
                    return Fail(session, HeartbeatStatus.BadPayload, "inner seq");

                var challenge = payload.Str("c");
                if (challenge != session.Challenge && challenge != session.PreviousChallenge)
                    return Fail(session, HeartbeatStatus.BadChallenge, "stale challenge");

                // Accept: advance sequence, ratchet the key, rotate the challenge.
                session.Seq = seq;
                session.Key = SentinelCrypto.Sha256(SentinelCrypto.Concat(session.Key, mac));
                session.PreviousChallenge = session.Challenge;
                session.Challenge = NewChallenge();
                session.LastValidAt = t;
                session.MissingReported = false;

                return new HeartbeatResult { Status = HeartbeatStatus.Ok, Payload = payload, NextChallenge = session.Challenge };
            }
        }

        /// <summary>Players whose heartbeat is overdue. Each overdue session is reported once until it recovers.</summary>
        public List<(int player, TimeSpan silentFor)> FindMissing(DateTime? now = null)
        {
            var t = now ?? DateTime.UtcNow;
            var result = new List<(int, TimeSpan)>();
            foreach (var kv in _sessions)
            {
                var s = kv.Value;
                lock (s)
                {
                    var limit = s.Seq == 0 ? FirstHeartbeatGrace : MissingAfter;
                    var silent = t - s.LastValidAt;
                    if (silent > limit && !s.MissingReported)
                    {
                        s.MissingReported = true;
                        result.Add((kv.Key, silent));
                    }
                }
            }
            return result;
        }

        private static HeartbeatResult Fail(HeartbeatSession s, HeartbeatStatus status, string reason)
        {
            s.Failures++;
            return new HeartbeatResult { Status = status, Reason = reason };
        }

        private static string NewChallenge() => SentinelCrypto.ToHex(SentinelCrypto.RandomBytes(8));

        /// <summary>Random event name for this server boot: 16 hex chars, no recognisable prefix.</summary>
        public static string RandomEventName() => SentinelCrypto.ToHex(SentinelCrypto.RandomBytes(8));
    }
}
