using System;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Logging;
using Xunit;

public class StaffAlertTests
{
    private static Violation V(int player, string code, EnforcementAction action)
    {
        var ledger = new ViolationLedger(new ScoringPolicy());
        var v = new Violation(player, code, ViolationSource.Server);
        ledger.Record(v);
        typeof(Violation).GetProperty("Action")!.SetValue(v, action);
        return v;
    }

    [Fact]
    public void AlertsRespectMinActionCooldownAndBypass()
    {
        var cfg = new StaffAlertConfig { MinAction = "log", CooldownSeconds = 30 };
        var a = new StaffAlerts(cfg);
        var now = DateTime.UtcNow;
        var text = a.Message("Bob", V(3, "PLY_GODMODE_FLAG", EnforcementAction.Log), false, false, now);
        Assert.NotNull(text);
        Assert.Contains("Bob (#3) PLY_GODMODE_FLAG", text);
        Assert.Null(a.Message("Bob", V(3, "PLY_GODMODE_FLAG", EnforcementAction.Log), false, false, now.AddSeconds(5)));
        Assert.NotNull(a.Message("Bob", V(3, "PLY_GODMODE_FLAG", EnforcementAction.Kick), false, false, now.AddSeconds(6)));
        Assert.NotNull(a.Message("Bob", V(3, "PLY_GODMODE_FLAG", EnforcementAction.Log), false, false, now.AddSeconds(40)));
        Assert.Null(a.Message("Ann", V(4, "WPN_AIM_SNAP", EnforcementAction.Log), true, false, now));
        cfg.MinAction = "kick";
        Assert.Null(a.Message("Ann", V(4, "WPN_RANGE", EnforcementAction.Log), false, false, now));
        cfg.Enabled = false;
        Assert.Null(a.Message("Ann", V(4, "WPN_RANGE", EnforcementAction.Ban), false, false, now));
    }

    [Fact]
    public void RecentKeepsTheLastEntries()
    {
        var r = new RecentViolations(3);
        for (int i = 0; i < 5; i++) r.Add(new Violation(1, "C" + i, ViolationSource.Server));
        Assert.Equal(new[] { "C2", "C3", "C4" }, r.Of(1).ConvertAll(x => x.code));
        r.Forget(1);
        Assert.Empty(r.Of(1));
    }
}

public class ReportThrottleTests
{
    [Fact]
    public void RepeatsAreFoldedUntilTheActionEscalates()
    {
        var t = new ReportThrottle();
        var now = DateTime.UtcNow;
        Violation V(EnforcementAction a)
        {
            var v = new Violation(5, "WPN_PROJECTILE_ORIGIN", ViolationSource.Server);
            typeof(Violation).GetProperty("Action")!.SetValue(v, a);
            return v;
        }
        Assert.True(t.ShouldReport(V(EnforcementAction.Log), now, out _));
        Assert.False(t.ShouldReport(V(EnforcementAction.Log), now.AddMilliseconds(100), out _));
        Assert.False(t.ShouldReport(V(EnforcementAction.Log), now.AddMilliseconds(200), out _));
        Assert.True(t.ShouldReport(V(EnforcementAction.Kick), now.AddMilliseconds(300), out var folded));
        Assert.Equal(2, folded);
        Assert.False(t.ShouldReport(V(EnforcementAction.Kick), now.AddSeconds(1), out _));
        Assert.True(t.ShouldReport(V(EnforcementAction.Kick), now.AddSeconds(5), out folded));
        Assert.Equal(1, folded);
    }
}
