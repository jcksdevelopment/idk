using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading.Tasks;
using JcksAnticheat.Core.Licensing;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private bool _licensed;
        private bool _licenseRequired;
        private RSAParameters _licenseKey;
        private string _licenseUrl = "";
        private string _fingerprint = "";
        private DateTime _licenseRecheckAt = DateTime.MaxValue;
        private readonly ConcurrentQueue<LicenseResult> _licenseResults = new ConcurrentQueue<LicenseResult>();
        private static readonly HttpClient LicenseHttp = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };

        private static string? Embedded(string name)
        {
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
            {
                if (s == null) return null;
                using (var r = new StreamReader(s)) return r.ReadToEnd().Trim();
            }
        }

        private void InitLicense()
        {
            var pem = Embedded("license.pub.pem");
            if (string.IsNullOrEmpty(pem))
            {
                _licensed = true;
                Log("development build: no license.pub.pem embedded, license check disabled");
                return;
            }
            _licenseRequired = true;
            _licenseKey = LicenseClient.ParsePublicKeyPem(pem!);
            _licenseUrl = GetConvar("jcks_ac_license_url", Embedded("license.url") ?? "");
            _fingerprint = LicenseClient.Fingerprint(GetConvar("sv_projectName", ""), GetResourcePath(_resource), GetConvar("endpoint_add_tcp", ""));
            CheckLicense();
        }

        private string LicenseCachePath => Path.Combine(_dataDir, "license.token");

        private void CheckLicense()
        {
            var licenseKey = GetConvar("jcks_ac_license", "");
            if (string.IsNullOrWhiteSpace(licenseKey))
            {
                _licensed = false;
                Log("no license key: add  set jcks_ac_license \"JAC-XXXXX-...\"  to server.cfg. Anticheat inactive.");
                return;
            }
            if (string.IsNullOrWhiteSpace(_licenseUrl))
            {
                _licensed = false;
                Log("no license server URL configured (jcks_ac_license_url). Anticheat inactive.");
                return;
            }
            string? cached = File.Exists(LicenseCachePath) ? File.ReadAllText(LicenseCachePath) : null;
            var key = _licenseKey;
            var url = _licenseUrl;
            var fp = _fingerprint;
            Task.Run(async () => _licenseResults.Enqueue(await LicenseClient.ActivateAsync(LicenseHttp, url, licenseKey, key, fp, "1.0.0", cached).ConfigureAwait(false)));
        }

        private void DrainLicense(DateTime now)
        {
            if (_licenseRequired && now >= _licenseRecheckAt)
            {
                _licenseRecheckAt = DateTime.MaxValue;
                CheckLicense();
            }
            while (_licenseResults.TryDequeue(out var r))
            {
                bool was = _licensed;
                _licensed = r.Ok;
                if (r.Ok)
                {
                    try { File.WriteAllText(LicenseCachePath, r.Token); } catch { }
                    _licenseRecheckAt = now.AddHours(r.Offline ? 1 : 6);
                    if (!was) Log("license valid" + (r.Offline ? " (offline grace until " + r.ValidUntil.ToString("yyyy-MM-dd HH:mm") + " UTC)" : "") + ". Anticheat active.");
                }
                else
                {
                    _licenseRecheckAt = now.AddMinutes(10);
                    Log("license check failed: " + r.Reason + ". Anticheat inactive.");
                }
            }
        }
    }
}
