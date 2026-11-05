using System.Security.Cryptography;
using System.Text;
using JcksAnticheat.Core.Licensing;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class LicenseTests
{
    private static string B64Url(byte[] b) => Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static (string pem, Func<string, string> sign) NewKey()
    {
        var rsa = RSA.Create(2048);
        return (rsa.ExportSubjectPublicKeyInfoPem(), payload =>
        {
            var body = B64Url(Encoding.UTF8.GetBytes(payload));
            return body + "." + B64Url(rsa.SignData(Encoding.UTF8.GetBytes(body), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1));
        });
    }

    private static long Unix(DateTime t) => new DateTimeOffset(t).ToUnixTimeSeconds();

    [Fact]
    public void ValidTokenForThisServerIsAccepted()
    {
        var (pem, sign) = NewKey();
        var now = DateTime.UtcNow;
        var token = sign($"{{\"f\":\"fp1\",\"n\":\"abc\",\"iat\":{Unix(now)},\"exp\":{Unix(now.AddHours(24))}}}");
        var r = LicenseClient.VerifyToken(token, LicenseClient.ParsePublicKeyPem(pem), "fp1", "abc", now, false);
        Assert.True(r.Ok, r.Reason);
    }

    [Fact]
    public void ForgedOtherServerStaleAndExpiredTokensAreRejected()
    {
        var (pem, sign) = NewKey();
        var (_, otherSign) = NewKey();
        var key = LicenseClient.ParsePublicKeyPem(pem);
        var now = DateTime.UtcNow;
        string P(string f, string n, DateTime iat, DateTime exp) => $"{{\"f\":\"{f}\",\"n\":\"{n}\",\"iat\":{Unix(iat)},\"exp\":{Unix(exp)}}}";

        Assert.Contains("signature", LicenseClient.VerifyToken(otherSign(P("fp1", "a", now, now.AddHours(1))), key, "fp1", "a", now, false).Reason);
        Assert.Contains("another server", LicenseClient.VerifyToken(sign(P("fp2", "a", now, now.AddHours(1))), key, "fp1", "a", now, false).Reason);
        Assert.Contains("nonce", LicenseClient.VerifyToken(sign(P("fp1", "old", now, now.AddHours(1))), key, "fp1", "a", now, false).Reason);
        Assert.Contains("expired", LicenseClient.VerifyToken(sign(P("fp1", "a", now.AddHours(-30), now.AddHours(-6))), key, "fp1", "a", now, false).Reason);
        var tampered = sign(P("fp1", "a", now, now.AddHours(1)));
        Assert.False(LicenseClient.VerifyToken("x" + tampered, key, "fp1", "a", now, false).Ok);
    }

    [Fact]
    public void OfflineGraceAcceptsRecentCachedTokenOnly()
    {
        var (pem, sign) = NewKey();
        var key = LicenseClient.ParsePublicKeyPem(pem);
        var now = DateTime.UtcNow;
        var recent = sign($"{{\"f\":\"fp\",\"n\":\"x\",\"iat\":{Unix(now.AddHours(-30))},\"exp\":{Unix(now.AddHours(-6))}}}");
        var r = LicenseClient.VerifyToken(recent, key, "fp", null, now, allowOfflineGrace: true);
        Assert.True(r.Ok && r.Offline);
        var old = sign($"{{\"f\":\"fp\",\"n\":\"x\",\"iat\":{Unix(now.AddHours(-80))},\"exp\":{Unix(now.AddHours(-56))}}}");
        Assert.False(LicenseClient.VerifyToken(old, key, "fp", null, now, allowOfflineGrace: true).Ok);
    }

    [Fact]
    public void TokenSignedByTheNodeLicenseServerVerifies()
    {
        var node = (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':').Select(p => Path.Combine(p, "node")).FirstOrDefault(File.Exists);
        if (node == null) return;
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "license-server"))) dir = dir.Parent;
        var script = "import { generateKeyPairSync } from 'node:crypto'; import { signToken } from './lib.mjs';" +
                     "const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });" +
                     "const now = Math.floor(Date.now()/1000);" +
                     "console.log(publicKey.export({ type: 'spki', format: 'pem' }).replace(/\\n/g, '|'));" +
                     "console.log(signToken(privateKey.export({ type: 'pkcs8', format: 'pem' }), { f: 'fp9', n: 'nn', iat: now, exp: now + 60 }));";
        var psi = new System.Diagnostics.ProcessStartInfo(node, new[] { "--input-type=module", "-e", script })
        {
            WorkingDirectory = Path.Combine(dir!.FullName, "license-server"), RedirectStandardOutput = true, RedirectStandardError = true,
        };
        using var p = System.Diagnostics.Process.Start(psi)!;
        var lines = p.StandardOutput.ReadToEnd().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        p.WaitForExit();
        Assert.True(lines.Length >= 2, p.StandardError.ReadToEnd());
        var key = LicenseClient.ParsePublicKeyPem(lines[0].Replace('|', '\n'));
        var r = LicenseClient.VerifyToken(lines[1], key, "fp9", "nn", DateTime.UtcNow, false);
        Assert.True(r.Ok, r.Reason);
    }
}
