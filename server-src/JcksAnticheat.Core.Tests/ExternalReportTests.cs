using System;
using System.Collections.Generic;
using JcksAnticheat.Core.Detection;
using Xunit;

public class ExternalReportTests
{
    [Fact]
    public void CodesAreNormalisedAndPrefixed()
    {
        Assert.Equal("EXT_MONEY_EXPLOIT", ExternalReport.Normalize("money-exploit"));
        Assert.Equal("EXT_ITEM_DUPE", ExternalReport.Normalize("EXT_item dupe"));
        Assert.Null(ExternalReport.Normalize("bad;code"));
        Assert.Null(ExternalReport.Normalize(""));
    }

    [Fact]
    public void EvidenceIsBoundedAndPerMinuteCapped()
    {
        var details = new Dictionary<string, object?> { ["amount"] = 500000, ["note"] = new string('x', 500), ["obj"] = new object() };
        var now = new DateTime(2026, 1, 1);
        var v = ExternalReport.Create(77, "money", "my_bank", details, now, maxPerMinute: 2);
        Assert.NotNull(v);
        Assert.Equal("EXT_MONEY", v!.Code);
        Assert.Equal("my_bank", v.Evidence["resource"]);
        Assert.Equal(200, ((string)v.Evidence["note"]!).Length);
        Assert.False(v.Evidence.ContainsKey("obj"));
        Assert.NotNull(ExternalReport.Create(77, "money", "my_bank", null, now, maxPerMinute: 2));
        Assert.Null(ExternalReport.Create(77, "money", "my_bank", null, now, maxPerMinute: 2));
        Assert.NotNull(ExternalReport.Create(77, "money", "my_bank", null, now.AddMinutes(2), maxPerMinute: 2));
    }

    [Fact]
    public void ExternalCodesScoreWithDefaultOrOverride()
    {
        var policy = new ScoringPolicy();
        var ledger = new ViolationLedger(policy);
        Assert.Equal(ExternalReport.DefaultSeverity, ledger.SeverityOf("EXT_MONEY"));
        policy.SeverityOverrides["EXT_MONEY"] = 90;
        Assert.Equal(90, ledger.SeverityOf("EXT_MONEY"));
    }
}
