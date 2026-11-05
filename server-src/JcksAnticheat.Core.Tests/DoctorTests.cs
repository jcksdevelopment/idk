using System.Linq;
using JcksAnticheat.Core.Audit;
using Xunit;

public class DoctorTests
{
    [Fact]
    public void GoodSetupHasNoWarnings()
    {
        var r = Doctor.Check(new DoctorInput { OneSync = "on", ShieldedResources = 30, ResourcesWithClientCode = 30, Countermeasures = true });
        Assert.DoesNotContain(r, x => x.level == "warn" || x.level == "fail");
    }

    [Fact]
    public void MissingPiecesAreReported()
    {
        var r = Doctor.Check(new DoctorInput
        {
            OneSync = "legacy", ResourcesWithClientCode = 10, VisionEnabled = true, DashboardEnabled = true,
            DiscordEnabled = true, LicenseRequired = true, DryRun = true,
        });
        Assert.Equal(2, r.Count(x => x.level == "fail"));
        Assert.True(r.Count(x => x.level == "warn") >= 5);
        Assert.Contains(r, x => x.text.Contains("shield install"));
        Assert.Contains(r, x => x.text.Contains("dryRun"));
    }
}

public class AuditExtraTests
{
    [Fact]
    public void DevModeAndRaisedLimitersAreReported()
    {
        var set = new System.Collections.Generic.Dictionary<string, string>
        {
            ["onesync"] = "on", ["sv_devMode"] = "true", ["rateLimiter_netEvent_rate"] = "1000", ["rateLimiter_stateBag_burst"] = "200",
        };
        var f = ServerAudit.Evaluate((n, d) => set.TryGetValue(n, out var v) ? v : d);
        Assert.Contains(f, x => x.Convar == "sv_devMode" && x.Severity == "high");
        Assert.Contains(f, x => x.Convar == "rateLimiter_netEvent_rate");
        Assert.DoesNotContain(f, x => x.Convar == "rateLimiter_stateBag_burst");
    }

    [Fact]
    public void ArtifactBuildIsParsedAndChecked()
    {
        Assert.Equal(12345, ServerAudit.ArtifactBuild("FXServer-master SERVER v1.0.0.12345 linux"));
        Assert.Null(ServerAudit.ArtifactBuild("FXServer-unknown"));
        var old = Doctor.Check(new DoctorInput { OneSync = "on", ArtifactBuild = 7290, Countermeasures = true });
        Assert.Contains(old, x => x.level == "warn" && x.text.Contains("7290"));
        var recent = Doctor.Check(new DoctorInput { OneSync = "on", ArtifactBuild = 13000, Countermeasures = true });
        Assert.DoesNotContain(recent, x => x.level == "warn" || x.level == "fail");
    }
}
