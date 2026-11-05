using System;
using System.Security.Cryptography;

namespace JcksAnticheat.Core.Crypto
{
    /// <summary>
    /// Server half of the heartbeat crypto. Byte-compatible with resource/jcks_anticheat/shared/crypto.lua:
    /// SHA-256, HMAC-SHA256, and a SHA-256-CTR stream where block i = SHA256(key || nonce || uint32_be(i)).
    /// </summary>
    public static class AcCrypto
    {
        public static byte[] Sha256(byte[] data)
        {
            using (var sha = SHA256.Create()) return sha.ComputeHash(data);
        }

        public static byte[] Hmac(byte[] key, byte[] message)
        {
            using (var h = new HMACSHA256(key)) return h.ComputeHash(message);
        }

        public static byte[] Ctr(byte[] key, byte[] nonce, byte[] data)
        {
            var output = new byte[data.Length];
            var blockInput = new byte[key.Length + nonce.Length + 4];
            Buffer.BlockCopy(key, 0, blockInput, 0, key.Length);
            Buffer.BlockCopy(nonce, 0, blockInput, key.Length, nonce.Length);
            int counterOffset = key.Length + nonce.Length;

            using (var sha = SHA256.Create())
            {
                uint counter = 0;
                for (int pos = 0; pos < data.Length; pos += 32, counter++)
                {
                    blockInput[counterOffset] = (byte)(counter >> 24);
                    blockInput[counterOffset + 1] = (byte)(counter >> 16);
                    blockInput[counterOffset + 2] = (byte)(counter >> 8);
                    blockInput[counterOffset + 3] = (byte)counter;
                    var block = sha.ComputeHash(blockInput);
                    int take = Math.Min(32, data.Length - pos);
                    for (int i = 0; i < take; i++) output[pos + i] = (byte)(data[pos + i] ^ block[i]);
                }
            }
            return output;
        }

        public static byte[] Concat(params byte[][] parts)
        {
            int len = 0;
            foreach (var p in parts) len += p.Length;
            var result = new byte[len];
            int off = 0;
            foreach (var p in parts)
            {
                Buffer.BlockCopy(p, 0, result, off, p.Length);
                off += p.Length;
            }
            return result;
        }

        public static byte[] UInt32BE(uint v) => new[] { (byte)(v >> 24), (byte)(v >> 16), (byte)(v >> 8), (byte)v };

        public static bool FixedTimeEquals(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            int diff = 0;
            for (int i = 0; i < a.Length; i++) diff |= a[i] ^ b[i];
            return diff == 0;
        }

        public static byte[] RandomBytes(int count)
        {
            var bytes = new byte[count];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
            return bytes;
        }

        public static string ToHex(byte[] bytes)
        {
            var c = new char[bytes.Length * 2];
            for (int i = 0; i < bytes.Length; i++)
            {
                int b = bytes[i];
                c[i * 2] = HexDigit(b >> 4);
                c[i * 2 + 1] = HexDigit(b & 0xF);
            }
            return new string(c);
        }

        /// <summary>Parses lowercase or uppercase hex. Returns null on malformed input instead of throwing.</summary>
        public static byte[]? FromHex(string? hex, int maxBytes = 1 << 16)
        {
            if (hex == null || (hex.Length & 1) != 0 || hex.Length / 2 > maxBytes) return null;
            var bytes = new byte[hex.Length / 2];
            for (int i = 0; i < bytes.Length; i++)
            {
                int hi = HexValue(hex[i * 2]), lo = HexValue(hex[i * 2 + 1]);
                if (hi < 0 || lo < 0) return null;
                bytes[i] = (byte)((hi << 4) | lo);
            }
            return bytes;
        }

        private static char HexDigit(int v) => (char)(v < 10 ? '0' + v : 'a' + v - 10);

        private static int HexValue(char c)
        {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            return -1;
        }
    }
}
