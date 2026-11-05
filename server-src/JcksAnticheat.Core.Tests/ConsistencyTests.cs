using System.Text.RegularExpressions;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class ConsistencyTests
{
    private static string Repo()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat"))) dir = dir.Parent;
        return dir!.FullName;
    }

    private static string Res(string file) => Path.Combine(Repo(), "resource", "jcks_anticheat", file);

    [Fact]
    public void EveryDetectionCodeIsDocumentedInTheThreatMatrix()
    {
        var matrix = File.ReadAllText(Path.Combine(Repo(), "docs", "THREAT_MATRIX.md"));
        var documented = Regex.Matches(matrix, @"^\| `([A-Z_]+)` \|", RegexOptions.Multiline).Select(m => m.Groups[1].Value).ToHashSet();
        var codes = ViolationCatalog.DefaultSeverity.Keys.ToHashSet();
        Assert.Empty(codes.Except(documented));
        Assert.Empty(documented.Except(codes));
    }

    [Fact]
    public void EveryClientFlagCodeIsInTheCatalog()
    {
        var lua = string.Concat(Directory.GetFiles(Res("client"), "*.lua", SearchOption.AllDirectories).Select(File.ReadAllText));
        var flagged = Regex.Matches(lua, @"S\.flag\(""([A-Z_]+)""").Select(m => m.Groups[1].Value).ToHashSet();
        Assert.DoesNotContain(flagged, c => !ViolationCatalog.DefaultSeverity.ContainsKey(c));
    }

    [Fact]
    public void SchemaAndConfigCoverEachOther()
    {
        var config = (Dictionary<string, object?>)MiniJson.Parse(File.ReadAllText(Res("config.json")))!;
        var schema = MiniJson.Parse(File.ReadAllText(Res("settings.schema.json")));
        var keys = schema.Arr("sections")!.OfType<Dictionary<string, object?>>()
            .SelectMany(s => s.Arr("fields")!.OfType<Dictionary<string, object?>>()).Select(f => f.Str("key")!).ToList();
        Assert.Equal(keys.Count, keys.Distinct().Count());
        object? Get(string path) => path.Split('.').Aggregate((object?)config, (o, k) => o is Dictionary<string, object?> d && d.TryGetValue(k, out var v) ? v : null);
        Assert.DoesNotContain(keys, k => Get(k) == null && !k.EndsWith("Blacklist") && !k.Contains("allowedPedModels"));

        var leaves = new List<string>();
        void Walk(object? o, string prefix)
        {
            if (o is Dictionary<string, object?> d && !(prefix is "scoring.severity" or "protectedEvents" or "integrations.resources" or "antiDump.resources"))
                foreach (var kv in d) Walk(kv.Value, prefix.Length == 0 ? kv.Key : prefix + "." + kv.Key);
            else leaves.Add(prefix);
        }
        Walk(config, "");
        Assert.DoesNotContain(leaves, l => !keys.Contains(l));
    }

    [Fact]
    public void ShippedConfigEqualsItsOwnSerialisation()
    {
        var cfg = AnticheatConfig.Parse(File.ReadAllText(Res("config.json")));
        Assert.Empty(cfg.Validate());
        var keysWritten = ((Dictionary<string, object?>)MiniJson.Parse(cfg.ToPrettyJson())!).Keys.OrderBy(k => k).ToList();
        var keysShipped = ((Dictionary<string, object?>)MiniJson.Parse(File.ReadAllText(Res("config.json")))!).Keys.OrderBy(k => k).ToList();
        Assert.Equal(keysShipped, keysWritten);
    }

    [Fact]
    public void ManifestReferencesOnlyExistingFilesOrBuildOutputs()
    {
        var manifest = File.ReadAllText(Res("fxmanifest.lua"));
        foreach (Match m in Regex.Matches(manifest, @"""([^""@]+\.(lua|html|js|css|json))"""))
        {
            var pattern = m.Groups[1].Value;
            var dir = Path.GetDirectoryName(Res(pattern))!;
            var files = Directory.Exists(dir) ? Directory.GetFiles(dir, Path.GetFileName(pattern)) : Array.Empty<string>();
            Assert.True(files.Length > 0, "fxmanifest references a missing file: " + pattern);
        }
        var dlls = Regex.Matches(manifest, @"""server/([^""]+\.dll)""").Select(m => m.Groups[1].Value).ToList();
        Assert.Equal(new[] { "JcksAnticheat.Core.net.dll", "JcksAnticheat.Server.net.dll" }, dlls);
        var csprojNames = Directory.GetFiles(Path.Combine(Repo(), "server-src"), "*.csproj", SearchOption.AllDirectories)
            .Select(p => Regex.Match(File.ReadAllText(p), "<AssemblyName>(.+)</AssemblyName>").Groups[1].Value + ".dll");
        Assert.All(dlls, d => Assert.Contains(d, csprojNames));
    }

    [Fact]
    public void CodeHasNoComments()
    {
        var root = Repo();
        var offenders = new List<string>();
        foreach (var f in Directory.GetFiles(Path.Combine(root, "resource"), "*.lua", SearchOption.AllDirectories))
            offenders.AddRange(File.ReadLines(f).Select((l, i) => (l, i)).Where(x => Regex.IsMatch(x.l, @"^\s*--")).Select(x => $"{f}:{x.i + 1}"));
        foreach (var f in Directory.GetFiles(Path.Combine(root, "server-src"), "*.cs", SearchOption.AllDirectories).Where(p => !p.Contains("/obj/") && !p.Contains("/bin/")))
            offenders.AddRange(File.ReadLines(f).Select((l, i) => (l, i)).Where(x => Regex.IsMatch(x.l, @"^\s*(//|/\*)")).Select(x => $"{f}:{x.i + 1}"));
        Assert.Empty(offenders);
    }
}
