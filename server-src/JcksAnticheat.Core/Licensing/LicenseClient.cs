using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Licensing
{
    public sealed class LicenseResult
    {
        public bool Ok { get; set; }
        public bool Offline { get; set; }
        public string Reason { get; set; } = "";
        public string? Token { get; set; }
        public DateTime ValidUntil { get; set; }
    }

    public static class LicenseClient
    {
        public static readonly TimeSpan OfflineGrace = TimeSpan.FromHours(72);

        public static string Fingerprint(string projectName, string serverDataPath, string port)
        {
            using (var sha = SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(projectName + "|" + serverDataPath.Replace('\\', '/').TrimEnd('/') + "|" + port))).Replace("-", "").ToLowerInvariant();
        }

        public static RSAParameters ParsePublicKeyPem(string pem)
        {
            var b64 = new StringBuilder();
            foreach (var line in pem.Split('\n'))
            {
                var l = line.Trim();
                if (l.Length == 0 || l.StartsWith("-----", StringComparison.Ordinal)) continue;
                b64.Append(l);
            }
            var der = Convert.FromBase64String(b64.ToString());
            int i = 0;
            ReadSeq(der, ref i);
            int algEnd = ReadSeq(der, ref i);
            i = algEnd;
            Expect(der, ref i, 0x03);
            ReadLen(der, ref i);
            i++;
            ReadSeq(der, ref i);
            var modulus = ReadInt(der, ref i);
            var exponent = ReadInt(der, ref i);
            return new RSAParameters { Modulus = modulus, Exponent = exponent };
        }

        public static bool VerifySignature(RSAParameters key, string body, byte[] signature)
        {
            using (var rsa = RSA.Create())
            {
                rsa.ImportParameters(key);
                return rsa.VerifyData(Encoding.UTF8.GetBytes(body), signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
            }
        }

        public static LicenseResult VerifyToken(string? token, RSAParameters key, string fingerprint, string? nonce, DateTime now, bool allowOfflineGrace)
        {
            var fail = new LicenseResult { Ok = false };
            if (string.IsNullOrEmpty(token)) { fail.Reason = "no token"; return fail; }
            var parts = token!.Split('.');
            if (parts.Length != 2) { fail.Reason = "malformed token"; return fail; }
            byte[] sig;
            string json;
            try
            {
                sig = FromB64Url(parts[1]);
                json = Encoding.UTF8.GetString(FromB64Url(parts[0]));
            }
            catch (FormatException) { fail.Reason = "malformed token"; return fail; }
            if (!VerifySignature(key, parts[0], sig)) { fail.Reason = "signature does not match the embedded public key"; return fail; }
            if (!MiniJson.TryParse(json, out var parsed) || !(parsed is Dictionary<string, object?> p)) { fail.Reason = "bad payload"; return fail; }
            if (p.Str("f") != fingerprint) { fail.Reason = "token belongs to another server"; return fail; }
            if (nonce != null && p.Str("n") != nonce) { fail.Reason = "stale token (nonce mismatch)"; return fail; }
            var iat = DateTimeOffset.FromUnixTimeSeconds((long)(p.Num("iat") ?? 0)).UtcDateTime;
            var exp = DateTimeOffset.FromUnixTimeSeconds((long)(p.Num("exp") ?? 0)).UtcDateTime;
            var until = allowOfflineGrace ? (iat + OfflineGrace > exp ? iat + OfflineGrace : exp) : exp;
            if (now > until) { fail.Reason = "license token expired"; return fail; }
            return new LicenseResult { Ok = true, Token = token, ValidUntil = until, Offline = allowOfflineGrace && now > exp };
        }

        /// <summary>Activates online; on a network failure falls back to the cached token within the offline grace.</summary>
        public static async Task<LicenseResult> ActivateAsync(HttpClient http, string url, string licenseKey, RSAParameters key, string fingerprint, string version, string? cachedToken)
        {
            var nonce = Guid.NewGuid().ToString("N");
            try
            {
                var body = MiniJson.Serialize(new Dictionary<string, object?> { ["key"] = licenseKey, ["fingerprint"] = fingerprint, ["nonce"] = nonce, ["version"] = version });
                using (var res = await http.PostAsync(url.TrimEnd('/') + "/v1/activate", new StringContent(body, Encoding.UTF8, "application/json")).ConfigureAwait(false))
                {
                    var text = await res.Content.ReadAsStringAsync().ConfigureAwait(false);
                    var parsed = MiniJson.TryParse(text, out var o) ? o : null;
                    if (res.StatusCode == HttpStatusCode.Forbidden)
                        return new LicenseResult { Ok = false, Reason = parsed.Str("error") ?? "license refused" };
                    if (res.IsSuccessStatusCode)
                        return VerifyToken(parsed.Str("token"), key, fingerprint, nonce, DateTime.UtcNow, allowOfflineGrace: false);
                }
            }
            catch (Exception) { }
            var cached = VerifyToken(cachedToken, key, fingerprint, null, DateTime.UtcNow, allowOfflineGrace: true);
            if (cached.Ok) { cached.Offline = true; return cached; }
            return new LicenseResult { Ok = false, Reason = "license server unreachable and no valid cached activation" };
        }

        private static byte[] FromB64Url(string s)
        {
            s = s.Replace('-', '+').Replace('_', '/');
            switch (s.Length % 4) { case 2: s += "=="; break; case 3: s += "="; break; }
            return Convert.FromBase64String(s);
        }

        private static void Expect(byte[] d, ref int i, byte tag)
        {
            if (d[i++] != tag) throw new FormatException("unexpected DER tag");
        }

        private static int ReadLen(byte[] d, ref int i)
        {
            int b = d[i++];
            if (b < 0x80) return b;
            int n = b & 0x7f, len = 0;
            for (int k = 0; k < n; k++) len = (len << 8) | d[i++];
            return len;
        }

        private static int ReadSeq(byte[] d, ref int i)
        {
            Expect(d, ref i, 0x30);
            int len = ReadLen(d, ref i);
            return i + len;
        }

        private static byte[] ReadInt(byte[] d, ref int i)
        {
            Expect(d, ref i, 0x02);
            int len = ReadLen(d, ref i);
            int start = i;
            i += len;
            while (len > 1 && d[start] == 0) { start++; len--; }
            var v = new byte[len];
            Array.Copy(d, start, v, 0, len);
            return v;
        }
    }
}
