using System.Diagnostics;
using Sentinel.Core.Crypto;
using Sentinel.Core.Heartbeat;
using Sentinel.Core.Json;
using Xunit;

namespace Sentinel.Core.Tests;

/// <summary>
/// End-to-end: the real client Lua (crypto.lua, main.lua, heartbeat.lua) runs under lua5.4 with
/// stubbed natives and produces heartbeats; the C# HeartbeatManager verifies them.
/// </summary>
public class HeartbeatInteropTests
{
    private static string ResourceRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "sentinel"))) dir = dir.Parent;
        return dir == null ? throw new InvalidOperationException("resource/sentinel not found") : Path.Combine(dir.FullName, "resource", "sentinel");
    }

    private static string? LuaBinary()
    {
        foreach (var name in new[] { "lua5.4", "lua" })
            foreach (var p in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':'))
                if (File.Exists(Path.Combine(p, name))) return Path.Combine(p, name);
        return null;
    }

    /// <summary>lua5.4 is required unless SENTINEL_SKIP_LUA=1 is set explicitly.</summary>
    private static string? RequireLua()
    {
        var lua = LuaBinary();
        if (lua == null && Environment.GetEnvironmentVariable("SENTINEL_SKIP_LUA") != "1")
            Assert.Fail("lua5.4 not found on PATH. Install it (apt install lua5.4) or set SENTINEL_SKIP_LUA=1.");
        return lua;
    }

    private sealed class LuaClient : IDisposable
    {
        private readonly Process _proc;
        public LuaClient(string lua, int heartbeats)
        {
            var harness = Path.Combine(AppContext.BaseDirectory, "lua", "harness.lua");
            _proc = Process.Start(new ProcessStartInfo(lua)
            {
                ArgumentList = { harness, ResourceRoot(), heartbeats.ToString() },
                RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false,
            })!;
        }

        public void Send(string line) { _proc.StandardInput.WriteLine(line); _proc.StandardInput.Flush(); }

        public Dictionary<string, object?> Read()
        {
            var line = _proc.StandardOutput.ReadLine() ?? throw new InvalidOperationException("lua exited: " + _proc.StandardError.ReadToEnd());
            return (Dictionary<string, object?>)MiniJson.Parse(line)!;
        }

        public void Dispose()
        {
            try { _proc.StandardInput.Close(); if (!_proc.WaitForExit(5000)) _proc.Kill(); } catch { }
            _proc.Dispose();
        }
    }

    private static string InitPayload(string key, string challenge) => MiniJson.Serialize(new Dictionary<string, object?>
    {
        ["k"] = key, ["c"] = challenge, ["hb"] = "hb_evt", ["ack"] = "ack_evt", ["gr"] = "gr_evt",
        ["sr"] = "sr_evt", ["su"] = "su_evt", ["iv"] = 5000, ["wb"] = new List<object?>(), ["rs"] = new List<object?>(), ["mh"] = 200,
    });

    [Fact]
    public void RealLuaClientHeartbeatsVerifyOnServer()
    {
        var lua = RequireLua();
        if (lua == null) return;

        var mgr = new HeartbeatManager();
        var (key, challenge) = mgr.Begin(7);
        using var client = new LuaClient(lua, 3);
        client.Send(InitPayload(key, challenge));

        var hello = client.Read();
        Assert.Equal("sentinel:hello", hello["event"]);

        for (int i = 1; i <= 3; i++)
        {
            var hb = client.Read();
            Assert.Equal("hb_evt", hb["event"]);
            var args = (List<object?>)hb["args"]!;
            var result = mgr.Verify(7, args[0], (string)args[1]!, (string)args[2]!, (string)args[3]!);
            Assert.True(result.Ok, $"heartbeat {i}: {result.Status} {result.Reason}");
            Assert.Equal((double)i, result.Payload.Num("s"));
            Assert.Equal(200.0, result.Payload.Obj("st").Num("h"));
            if (i == 1)
            {
                var flags = result.Payload.Arr("f")!;
                Assert.Single(flags);
                Assert.Equal("PLY_GODMODE_FLAG", flags[0].Str("c"));
            }
            client.Send(result.NextChallenge!);
        }
    }

    [Fact]
    public void TamperedReplayedAndForgedHeartbeatsAreRejected()
    {
        var lua = RequireLua();
        if (lua == null) return;

        var mgr = new HeartbeatManager();
        var (key, challenge) = mgr.Begin(9);
        using var client = new LuaClient(lua, 2);
        client.Send(InitPayload(key, challenge));
        client.Read(); // hello

        var args = (List<object?>)client.Read()["args"]!;
        var ct = (string)args[2]!;
        var tampered = (ct[0] == '0' ? "1" : "0") + ct.Substring(1);
        Assert.Equal(HeartbeatStatus.BadMac, mgr.Verify(9, args[0], (string)args[1]!, tampered, (string)args[3]!).Status);

        var ok = mgr.Verify(9, args[0], (string)args[1]!, ct, (string)args[3]!);
        Assert.True(ok.Ok);
        // Same packet again: sequence replay.
        Assert.Equal(HeartbeatStatus.Replay, mgr.Verify(9, args[0], (string)args[1]!, ct, (string)args[3]!).Status);

        // A forger who knows the original key but missed the ratchet produces a bad MAC.
        var keyBytes = SentinelCrypto.FromHex(key)!;
        var nonce = new byte[16];
        var plain = System.Text.Encoding.UTF8.GetBytes("{\"s\":2,\"c\":\"" + ok.NextChallenge + "\",\"f\":[]}");
        var forgedCt = SentinelCrypto.Ctr(keyBytes, nonce, plain);
        var forgedMac = SentinelCrypto.Hmac(keyBytes, SentinelCrypto.Concat(SentinelCrypto.UInt32BE(2), nonce, forgedCt));
        Assert.Equal(HeartbeatStatus.BadMac,
            mgr.Verify(9, 2, SentinelCrypto.ToHex(nonce), SentinelCrypto.ToHex(forgedCt), SentinelCrypto.ToHex(forgedMac)).Status);
        client.Send("-");
    }

    [Fact]
    public void MissingHeartbeatIsReportedOnce()
    {
        var mgr = new HeartbeatManager { MissingAfter = TimeSpan.FromSeconds(20), FirstHeartbeatGrace = TimeSpan.FromSeconds(90) };
        var t0 = DateTime.UtcNow;
        mgr.Begin(3, t0);
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(60)));
        Assert.Single(mgr.FindMissing(t0.AddSeconds(91)));
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(120)));
    }

    [Fact]
    public void CryptoMatchesLuaVectors()
    {
        // Vectors produced by resource/sentinel/shared/crypto.lua (see README "Verifying the crypto").
        var key = SentinelCrypto.Sha256(System.Text.Encoding.UTF8.GetBytes("k"));
        var ct = SentinelCrypto.Ctr(key, System.Text.Encoding.UTF8.GetBytes("nonce1234567890a"),
            System.Text.Encoding.UTF8.GetBytes("hello world, this is longer than thirty-two bytes!!"));
        Assert.Equal("98c8a39f954c5787e2991df591927bcb759c62321117f8bb38b29f38b2ef9005f9db756012ce2b37ed38edd969e9d65a1b69f6",
            SentinelCrypto.ToHex(ct));
        Assert.Equal("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
            SentinelCrypto.ToHex(SentinelCrypto.Hmac(System.Text.Encoding.UTF8.GetBytes("key"),
                System.Text.Encoding.UTF8.GetBytes("The quick brown fox jumps over the lazy dog"))));
    }
}

public class HandshakeTimeoutTests
{
    [Fact]
    public void PlayerWhoNeverSendsHelloIsReportedOnce()
    {
        var mgr = new HeartbeatManager { HandshakeTimeout = TimeSpan.FromSeconds(150) };
        var t0 = DateTime.UtcNow;
        mgr.ExpectHandshake(4, t0);
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(100)));
        var missing = mgr.FindMissing(t0.AddSeconds(151));
        Assert.Equal(4, Assert.Single(missing).player);
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(200)));
    }

    [Fact]
    public void HandshakeClearsTheExpectation()
    {
        var mgr = new HeartbeatManager();
        var t0 = DateTime.UtcNow;
        mgr.ExpectHandshake(5, t0);
        mgr.Begin(5, t0.AddSeconds(10));
        // Only the session's own first-heartbeat grace (90 s from Begin) applies now.
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(160 - 70)));
    }

    [Fact]
    public void DroppedPlayerIsNotReported()
    {
        var mgr = new HeartbeatManager();
        var t0 = DateTime.UtcNow;
        mgr.ExpectHandshake(6, t0);
        mgr.End(6);
        Assert.Empty(mgr.FindMissing(t0.AddSeconds(500)));
    }
}
