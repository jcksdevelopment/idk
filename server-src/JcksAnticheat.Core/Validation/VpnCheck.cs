using System;
using System.Collections.Concurrent;
using System.Linq;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace JcksAnticheat.Core.Validation
{
    public sealed class VpnConfig
    {
        public bool Enabled { get; set; }
        public string UrlTemplate { get; set; } = "https://proxycheck.io/v2/{ip}?vpn=1&key={key}";
        public string ApiKeyEnv { get; set; } = "JCKS_AC_VPN_API_KEY";
        public string BlockRegex { get; set; } = "\"proxy\"\\s*:\\s*\"yes\"";
        public int CacheHours { get; set; } = 24;
        public int TimeoutMs { get; set; } = 3000;
        public System.Collections.Generic.List<string> AllowIdentifiers { get; set; } = new System.Collections.Generic.List<string>();
    }

    public sealed class VpnChecker
    {
        private readonly VpnConfig _config;
        private readonly HttpClient _http;
        private readonly Func<string?> _key;
        private readonly ConcurrentDictionary<string, (bool vpn, DateTime at)> _cache = new ConcurrentDictionary<string, (bool, DateTime)>(StringComparer.Ordinal);

        public VpnChecker(VpnConfig config, HttpMessageHandler? handler = null, Func<string?>? key = null)
        {
            _config = config;
            _http = handler != null ? new HttpClient(handler) : new HttpClient();
            _key = key ?? (() => Environment.GetEnvironmentVariable(config.ApiKeyEnv));
        }

        public static bool IsPublicIp(string ip)
        {
            if (!System.Net.IPAddress.TryParse(ip, out var a) || System.Net.IPAddress.IsLoopback(a)) return false;
            var b = a.GetAddressBytes();
            if (b.Length != 4) return !a.IsIPv6LinkLocal && !a.IsIPv6SiteLocal;
            return !(b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168) || (b[0] == 100 && b[1] >= 64 && b[1] <= 127) || b[0] == 0);
        }

        public bool Allowed(System.Collections.Generic.IEnumerable<string> identifiers)
            => identifiers.Any(i => _config.AllowIdentifiers.Contains(i, StringComparer.OrdinalIgnoreCase));

        public async Task<bool?> IsVpnAsync(string ip, DateTime now)
        {
            if (!_config.Enabled || !IsPublicIp(ip)) return false;
            if (_cache.TryGetValue(ip, out var c) && now - c.at < TimeSpan.FromHours(_config.CacheHours)) return c.vpn;
            var url = _config.UrlTemplate.Replace("{ip}", Uri.EscapeDataString(ip)).Replace("{key}", Uri.EscapeDataString(_key() ?? ""));
            try
            {
                using var cts = new System.Threading.CancellationTokenSource(_config.TimeoutMs);
                using var resp = await _http.GetAsync(url, cts.Token).ConfigureAwait(false);
                if (!resp.IsSuccessStatusCode) return null;
                var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                bool vpn = Regex.IsMatch(body, _config.BlockRegex, RegexOptions.IgnoreCase, TimeSpan.FromMilliseconds(200));
                _cache[ip] = (vpn, now);
                return vpn;
            }
            catch (Exception)
            {
                return null;
            }
        }
    }
}
