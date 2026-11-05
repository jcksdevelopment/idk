using System.Diagnostics;
using JcksAnticheat.Core.Crypto;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Heartbeat;
using JcksAnticheat.Core.Json;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class HeartbeatInteropTests
{
    private static string ResourceRoot()
    {
        var overrideRoot = Environment.GetEnvironmentVariable("JCKS_AC_RESOURCE_ROOT");
        if (!string.IsNullOrEmpty(overrideRoot)) return Path.GetFullPath(overrideRoot);
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat"))) dir = dir.Parent;
        return dir == null ? throw new InvalidOperationException("resource/jcks_anticheat not found") : Path.Combine(dir.FullName, "resource", "jcks_anticheat");
    }

    private static string? LuaBinary()
    {
        foreach (var name in new[] { "lua5.4", "lua" })
            foreach (var p in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':'))
                if (File.Exists(Path.Combine(p, name))) return Path.Combine(p, name);
        return null;
    }

    private static string? RequireLua()
    {
        var lua = LuaBinary();
        if (lua == null && Environment.GetEnvironmentVariable("JCKS_AC_SKIP_LUA") != "1")
            Assert.Fail("lua5.4 not found on PATH. Install it (apt install lua5.4) or set JCKS_AC_SKIP_LUA=1.");
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
        Assert.Equal("jcks_anticheat:hello", hello["event"]);

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
        client.Read();

        var args = (List<object?>)client.Read()["args"]!;
        var ct = (string)args[2]!;
        var tampered = (ct[0] == '0' ? "1" : "0") + ct.Substring(1);
        Assert.Equal(HeartbeatStatus.BadMac, mgr.Verify(9, args[0], (string)args[1]!, tampered, (string)args[3]!).Status);

        var ok = mgr.Verify(9, args[0], (string)args[1]!, ct, (string)args[3]!);
        Assert.True(ok.Ok);
        Assert.Equal(HeartbeatStatus.Replay, mgr.Verify(9, args[0], (string)args[1]!, ct, (string)args[3]!).Status);

        var keyBytes = AcCrypto.FromHex(key)!;
        var nonce = new byte[16];
        var plain = System.Text.Encoding.UTF8.GetBytes("{\"s\":2,\"c\":\"" + ok.NextChallenge + "\",\"f\":[]}");
        var forgedCt = AcCrypto.Ctr(keyBytes, nonce, plain);
        var forgedMac = AcCrypto.Hmac(keyBytes, AcCrypto.Concat(AcCrypto.UInt32BE(2), nonce, forgedCt));
        Assert.Equal(HeartbeatStatus.BadMac,
            mgr.Verify(9, 2, AcCrypto.ToHex(nonce), AcCrypto.ToHex(forgedCt), AcCrypto.ToHex(forgedMac)).Status);
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
        var key = AcCrypto.Sha256(System.Text.Encoding.UTF8.GetBytes("k"));
        var ct = AcCrypto.Ctr(key, System.Text.Encoding.UTF8.GetBytes("nonce1234567890a"),
            System.Text.Encoding.UTF8.GetBytes("hello world, this is longer than thirty-two bytes!!"));
        Assert.Equal("98c8a39f954c5787e2991df591927bcb759c62321117f8bb38b29f38b2ef9005f9db756012ce2b37ed38edd969e9d65a1b69f6",
            AcCrypto.ToHex(ct));
        Assert.Equal("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
            AcCrypto.ToHex(AcCrypto.Hmac(System.Text.Encoding.UTF8.GetBytes("key"),
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

public class ShieldTests
{
    [Fact]
    public void ShieldCatchesInjectedLuaAndIgnoresResourceCode()
    {
        var lua = new[] { "lua5.4", "lua" }.SelectMany(n => (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':').Select(p => Path.Combine(p, n))).FirstOrDefault(File.Exists);
        if (lua == null)
        {
            if (Environment.GetEnvironmentVariable("JCKS_AC_SKIP_LUA") == "1") return;
            Assert.Fail("lua5.4 not found on PATH (or set JCKS_AC_SKIP_LUA=1).");
        }
        var root = Environment.GetEnvironmentVariable("JCKS_AC_RESOURCE_ROOT");
        if (string.IsNullOrEmpty(root))
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat"))) dir = dir.Parent;
            root = Path.Combine(dir!.FullName, "resource", "jcks_anticheat");
        }
        var psi = new System.Diagnostics.ProcessStartInfo(lua!) { RedirectStandardOutput = true, RedirectStandardError = true };
        psi.ArgumentList.Add(Path.Combine(AppContext.BaseDirectory, "lua", "shield_test.lua"));
        psi.ArgumentList.Add(root);
        using var p = System.Diagnostics.Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit();
        Assert.True(p.ExitCode == 0 && output.Contains("SHIELD OK"), output);
    }

    [Fact]
    public void InstallerPrependsOnceAndUninstallsCleanly()
    {
        const string manifest = "fx_version 'cerulean'\ngame 'gta5'\nclient_script 'client.lua'\nserver_script 'server.lua'\n";
        var (installed, changed) = ShieldInstaller.Install(manifest);
        Assert.True(changed);
        Assert.StartsWith("client_script \"@jcks_anticheat/shield/shield.lua\"", installed);
        Assert.False(ShieldInstaller.Install(installed).changed);
        Assert.Equal(manifest, ShieldInstaller.Uninstall(installed).manifest);
    }

    [Fact]
    public void InstallerSkipsServerOnlyResources()
        => Assert.False(ShieldInstaller.Install("fx_version 'cerulean'\nserver_scripts { 'a.lua' }\n").changed);
}

public class CountermeasureTests
{
    [Fact]
    public void ClientCountermeasuresFollowSettings()
    {
        var lua = new[] { "lua5.4", "lua" }.SelectMany(n => (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':').Select(p => Path.Combine(p, n))).FirstOrDefault(File.Exists);
        if (lua == null) { if (Environment.GetEnvironmentVariable("JCKS_AC_SKIP_LUA") == "1") return; Assert.Fail("lua5.4 not found"); }
        var root = Environment.GetEnvironmentVariable("JCKS_AC_RESOURCE_ROOT");
        if (string.IsNullOrEmpty(root))
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat"))) dir = dir.Parent;
            root = Path.Combine(dir!.FullName, "resource", "jcks_anticheat");
        }
        var psi = new System.Diagnostics.ProcessStartInfo(lua!) { RedirectStandardOutput = true, RedirectStandardError = true };
        psi.ArgumentList.Add(Path.Combine(AppContext.BaseDirectory, "lua", "countermeasures_test.lua"));
        psi.ArgumentList.Add(root);
        using var p = System.Diagnostics.Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit();
        Assert.True(p.ExitCode == 0 && output.Contains("COUNTERMEASURES OK"), output);
    }

    [Fact]
    public void LastGoodPositionSkipsViolatingSamples()
    {
        var mv = new JcksAnticheat.Core.Validation.MovementValidator(new JcksAnticheat.Core.Validation.MovementLimits());
        var t0 = DateTime.UtcNow;
        mv.Evaluate(1, new JcksAnticheat.Core.Validation.MovementSample(new JcksAnticheat.Core.Validation.Vec3(10, 10, 10), default, JcksAnticheat.Core.Validation.MovementMode.OnFoot, t0));
        mv.Evaluate(1, new JcksAnticheat.Core.Validation.MovementSample(new JcksAnticheat.Core.Validation.Vec3(5000, 0, 0), default, JcksAnticheat.Core.Validation.MovementMode.OnFoot, t0.AddSeconds(1)));
        Assert.Equal(10f, mv.LastGood(1)!.Value.X);
    }
}
