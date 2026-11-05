using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Audit;
using Xunit;

public class ServerAuditTests
{
    private static List<AuditFinding> Run(Dictionary<string, string> set)
        => ServerAudit.Evaluate((name, fallback) => set.TryGetValue(name, out var v) ? v : fallback);

    [Fact]
    public void DefaultServerGetsTheDocumentedSuggestions()
    {
        var f = Run(new Dictionary<string, string>());
        var byConvar = f.ToDictionary(x => x.Convar);
        Assert.Equal("high", byConvar["onesync"].Severity);
        Assert.Equal("2", byConvar["sv_filterRequestControl"].Recommended);
        Assert.Contains("sv_enableNetworkedSounds", byConvar.Keys);
        Assert.DoesNotContain("sv_scriptHookAllowed", byConvar.Keys);
        Assert.DoesNotContain("sv_enableNetworkedPhoneExplosions", byConvar.Keys);
    }

    [Fact]
    public void HardenedServerIsClean()
    {
        var f = Run(new Dictionary<string, string>
        {
            ["onesync"] = "on", ["sv_filterRequestControl"] = "2", ["sv_enableNetworkedSounds"] = "false",
            ["sv_enableNetworkedScriptEntityStates"] = "false", ["sv_entityLockdown"] = "relaxed", ["sv_pureLevel"] = "1",
            ["sv_stateBagStrictMode"] = "true", ["sv_protectServerEntities"] = "true", ["sv_requestParanoia"] = "1", ["sv_authMinTrust"] = "2",
        });
        Assert.Empty(f);
    }

    [Fact]
    public void DangerousSettingsAreHigh()
    {
        var f = Run(new Dictionary<string, string> { ["onesync"] = "on", ["sv_scriptHookAllowed"] = "true", ["sv_enableNetworkedPhoneExplosions"] = "1" });
        Assert.Equal(2, f.Count(x => x.Severity == "high"));
    }
}
