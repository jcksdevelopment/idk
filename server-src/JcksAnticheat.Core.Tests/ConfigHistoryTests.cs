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
