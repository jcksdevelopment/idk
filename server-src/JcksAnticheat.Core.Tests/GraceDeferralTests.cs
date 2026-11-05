using JcksAnticheat.Core.Detection;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class GraceDeferralTests
{
    private static readonly DateTime T0 = new(2026, 11, 5, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void ViolationIsHeldThenConfirmedWithoutGrace()
    {
        var d = new GraceDeferral();
        d.Add(1, "teleport", T0, new Violation(1, "MOV_TELEPORT", ViolationSource.Server), null);
        Assert.Empty(d.Resolve(T0.AddSeconds(1), _ => true));
        Assert.Single(d.Resolve(T0.AddSeconds(3), _ => true));
        Assert.Equal(0, d.Pending);
    }

    [Fact]
    public void GraceArrivingAfterTheDetectionCancelsIt()
    {
        var d = new GraceDeferral();
        var ran = false;
        d.Add(1, "teleport", T0, new Violation(1, "MOV_TELEPORT", ViolationSource.Server), () => ran = true);
        d.RecordGrant(1, "teleport", T0.AddSeconds(1.5));
        Assert.Empty(d.Resolve(T0.AddSeconds(3), _ => true));
        Assert.False(ran);
    }

    [Fact]
    public void GraceShortlyBeforeTheDetectionAlsoCounts()
    {
        var d = new GraceDeferral();
        d.RecordGrant(2, "heal", T0.AddSeconds(-2));
        d.Add(2, "heal", T0, new Violation(2, "PLY_HEALTH_REGEN", ViolationSource.Server), null);
        Assert.Empty(d.Resolve(T0.AddSeconds(3), _ => true));
    }

    [Fact]
    public void OldGraceDoesNotCoverANewDetection()
    {
        var d = new GraceDeferral();
        d.RecordGrant(3, "teleport", T0.AddSeconds(-60));
        d.Add(3, "teleport", T0, new Violation(3, "MOV_TELEPORT", ViolationSource.Server), null);
        Assert.Single(d.Resolve(T0.AddSeconds(3), _ => true));
    }

    [Fact]
    public void NoclipGraceCoversTeleportsAndOfflinePlayersAreDropped()
    {
        var d = new GraceDeferral();
        d.RecordGrant(4, "noclip", T0);
        d.Add(4, "teleport", T0, null, () => { });
        d.Add(5, "teleport", T0, null, () => { });
        Assert.Empty(d.Resolve(T0.AddSeconds(3), p => p != 5));
        Assert.Equal("teleport", GraceDeferral.KindFor("PLY_SPEED_FOOT"));
        Assert.Null(GraceDeferral.KindFor("WPN_RANGE"));
    }
}
