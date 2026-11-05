using JcksAnticheat.Core.Config;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class IntegrationTests
{
    private static string Presets()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat", "integrations.presets.json"))) dir = dir.Parent;
        return File.ReadAllText(Path.Combine(dir!.FullName, "resource", "jcks_anticheat", "integrations.presets.json"));
    }

    [Fact]
    public void PresetsApplyOnlyToRunningResourcesAndConfigOverrides()
    {
        var presets = IntegrationPolicy.ParsePresets(Presets());
        Assert.True(presets.Count > 30);
        Assert.All(presets.Values.SelectMany(v => v), b => Assert.True(Behaviours.IsKnown(b), b));

        var cfg = new IntegrationsConfig { Resources = { ["qb-ambulancejob"] = new List<string> { "heal" }, ["my_script"] = new List<string> { "*" } } };
        var running = new HashSet<string> { "qb-ambulancejob", "vMenu", "my_script" };
        var policy = IntegrationPolicy.Build(cfg, presets, running.Contains);

        Assert.True(policy.Allows("vMenu", "noclip"));
        Assert.False(policy.Allows("monitor", "noclip"));          // txAdmin not running here
        Assert.True(policy.Allows("qb-ambulancejob", "heal"));
        Assert.False(policy.Allows("qb-ambulancejob", "teleport")); // config replaced the preset
        Assert.True(policy.Allows("my_script", "godmode"));         // *
        Assert.False(policy.Allows("unknown", "heal"));
    }

    [Fact]
    public void PresetsCanBeSwitchedOff()
    {
        var policy = IntegrationPolicy.Build(new IntegrationsConfig { UsePresets = false }, IntegrationPolicy.ParsePresets(Presets()), _ => true);
        Assert.False(policy.Allows("vMenu", "noclip"));
    }

    [Fact]
    public void LearningSuggestsOnlyRepeatedUntrustedBehaviour()
    {
        var policy = IntegrationPolicy.Build(new IntegrationsConfig { Resources = { ["hospital"] = new List<string> { "heal" } } }, null, _ => true);
        var l = new IntegrationLearning();
        for (int i = 0; i < 5; i++) { l.Record("hospital", "heal"); l.Record("hospital", "teleport"); l.Record("garage", "vehicle"); }
        l.Record("once", "godmode");
        l.Record("evil", "notabehaviour");
        var s = l.Suggest(policy);
        Assert.Equal(new[] { "teleport" }, s["hospital"]);
        Assert.Equal(new[] { "vehicle" }, s["garage"]);
        Assert.False(s.ContainsKey("once"));
        Assert.False(s.ContainsKey("evil"));
    }

    [Fact]
    public void ConfigRoundTripsAndRejectsUnknownBehaviours()
    {
        var cfg = AnticheatConfig.Parse("{\"integrations\":{\"learning\":true,\"graceMs\":8000,\"resources\":{\"qb-garages\":[\"vehicle\",\"camera\"]}}}");
        var again = AnticheatConfig.Parse(cfg.ToPrettyJson());
        Assert.True(again.Integrations.Learning);
        Assert.Equal(new[] { "vehicle", "camera" }, again.Integrations.Resources["qb-garages"]);
        Assert.Throws<FormatException>(() => AnticheatConfig.ParseValidated("{\"integrations\":{\"resources\":{\"x\":[\"fly\"]}}}"));
    }
}
