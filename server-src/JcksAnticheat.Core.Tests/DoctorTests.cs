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
