using System;
using System.IO;
using JcksAnticheat.Core.Config;
using Xunit;

public class ConfigHistoryTests
{
    [Fact]
    public void KeepsNewestFirstSkipsDuplicatesAndTrims()
    {
        var dir = Path.Combine(Path.GetTempPath(), "jac-hist-" + Guid.NewGuid().ToString("N"));
        try
        {
            var h = new ConfigHistory(dir, keep: 3);
            var t = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc);
            h.Push("{\"a\":1}", t);
            h.Push("{\"a\":1}", t.AddSeconds(1));
            Assert.Single(h.Entries());
            for (int i = 2; i <= 5; i++) h.Push("{\"a\":" + i + "}", t.AddSeconds(i));
            Assert.Equal(3, h.Entries().Count);
            Assert.Equal("{\"a\":5}", h.Read(1));
            Assert.Equal("{\"a\":3}", h.Read(3));
            Assert.Null(h.Read(4));
            Assert.Null(h.Push("  ", t));
            Assert.Equal("2026-01-01 12:00:05 UTC", ConfigHistory.Label(h.Entries()[0]));
        }
        finally { if (Directory.Exists(dir)) Directory.Delete(dir, true); }
    }
}

public class EventZoneTests
{
    [Fact]
    public void ZonesCompileAndContain()
    {
        Assert.True(JcksAnticheat.Core.Validation.EventZones.TryCompile(new[] { "125.0", "111.1", "35.8", "15", "0", "0", "0", "5" }, out var zones));
        Assert.Equal(2, zones.Count);
        Assert.True(JcksAnticheat.Core.Validation.EventZones.Inside(zones, new JcksAnticheat.Core.Validation.Vec3(130, 111, 35), out _));
        Assert.True(JcksAnticheat.Core.Validation.EventZones.Inside(zones, new JcksAnticheat.Core.Validation.Vec3(1, 1, 1), out _));
        Assert.False(JcksAnticheat.Core.Validation.EventZones.Inside(zones, new JcksAnticheat.Core.Validation.Vec3(500, 500, 30), out var d));
        Assert.True(d > 300);
        Assert.False(JcksAnticheat.Core.Validation.EventZones.TryCompile(new[] { "1", "2", "3" }, out _));
        Assert.False(JcksAnticheat.Core.Validation.EventZones.TryCompile(new[] { "1", "2", "3", "-1" }, out _));
        Assert.False(JcksAnticheat.Core.Validation.EventZones.TryCompile(new[] { "a", "2", "3", "4" }, out _));
    }

    [Fact]
    public void ZonesRoundTripThroughConfigAndValidate()
    {
        var cfg = AnticheatConfig.Parse("{\"eventZones\":{\"job:startJob\":[\"125.0\",\"111.1\",\"35.8\",\"15\"]}}");
        Assert.Empty(cfg.Validate());
        var again = AnticheatConfig.Parse(JcksAnticheat.Core.Json.MiniJson.Serialize(cfg.ToJson()));
        Assert.Equal(new[] { "125.0", "111.1", "35.8", "15" }, again.EventZones["job:startJob"]);
        cfg.EventZones["bad"] = new System.Collections.Generic.List<string> { "1" };
        Assert.Contains(cfg.Validate(), e => e.Contains("eventZones"));
    }

    [Fact]
    public void CounterCountDoesNotAdd()
    {
        var c = new JcksAnticheat.Core.Detection.SlidingCounter();
        var now = DateTime.UtcNow;
        c.Add("k", now, TimeSpan.FromMinutes(1));
        c.Add("k", now, TimeSpan.FromMinutes(1));
        Assert.Equal(2, c.Count("k", now, TimeSpan.FromMinutes(1)));
        Assert.Equal(2, c.Count("k", now, TimeSpan.FromMinutes(1)));
        Assert.Equal(0, c.Count("k", now.AddMinutes(2), TimeSpan.FromMinutes(1)));
    }
}
