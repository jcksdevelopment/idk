using System;
using System.IO;
using System.Linq;
using Xunit;

public class ClientSimulationTests
{
    [Fact]
    public void EveryCheatScenarioIsDetectedAndUndoneAndCleanPlayersAreNot()
    {
        var lua = new[] { "lua5.4", "lua" }.SelectMany(n => (Environment.GetEnvironmentVariable("PATH") ?? "").Split(':').Select(p => Path.Combine(p, n))).FirstOrDefault(File.Exists);
        if (lua == null) { if (Environment.GetEnvironmentVariable("JCKS_AC_SKIP_LUA") == "1") return; Assert.Fail("lua5.4 not found"); }
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "tools", "sim"))) dir = dir.Parent;
        Assert.NotNull(dir);
        var psi = new System.Diagnostics.ProcessStartInfo(lua!) { RedirectStandardOutput = true, RedirectStandardError = true };
        psi.ArgumentList.Add(Path.Combine(dir!.FullName, "tools", "sim", "client_sim.lua"));
        psi.ArgumentList.Add(Path.Combine(dir.FullName, "resource", "jcks_anticheat"));
        psi.ArgumentList.Add("all");
        using var p = System.Diagnostics.Process.Start(psi)!;
        var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit();
        Assert.True(p.ExitCode == 0 && output.Contains("CLIENT SIM OK"), output);
    }
}
