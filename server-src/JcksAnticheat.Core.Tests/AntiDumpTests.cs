using JcksAnticheat.Core.AntiDump;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class AntiDumpTests
{
    [Fact]
    public void ExtractsLocalClientScriptsAndKeepsEverythingElse()
    {
        const string manifest = "fx_version 'cerulean'\ngame 'gta5'\nshared_script 'config.lua'\nclient_script 'client/single.lua'\nclient_scripts {\n  '@ox_lib/init.lua',\n  'client/*.lua',\n  'client/menu.lua'\n}\nserver_script 'server.lua'\nfiles { 'html/index.html' }\n";
        var (m, entries) = AntiDumpManifest.Extract(manifest);
        Assert.Equal(new[] { "client/*.lua", "client/menu.lua", "client/single.lua" }, entries.OrderBy(x => x));
        Assert.Contains("'@ox_lib/init.lua'", m);
        Assert.Contains("shared_script 'config.lua'", m);
        Assert.Contains("server_script 'server.lua'", m);
        Assert.DoesNotContain("client/menu.lua", m);
        Assert.True(AntiDumpManifest.IsProtected(m));
    }

    [Fact]
    public void ExpandsGlobsInsideTheResourceOnly()
    {
        var root = Path.Combine(Path.GetTempPath(), "jac-ad-" + Guid.NewGuid());
        Directory.CreateDirectory(Path.Combine(root, "client", "sub"));
        try
        {
            File.WriteAllText(Path.Combine(root, "client", "b.lua"), "");
            File.WriteAllText(Path.Combine(root, "client", "a.lua"), "");
            File.WriteAllText(Path.Combine(root, "client", "sub", "c.lua"), "");
            Assert.Equal(new[] { "client/a.lua", "client/b.lua" }, AntiDumpManifest.Expand(root, new[] { "client/*.lua" }));
            Assert.Equal(3, AntiDumpManifest.Expand(root, new[] { "client/**.lua" }).Count);
            Assert.Empty(AntiDumpManifest.Expand(root, new[] { "../etc/passwd" }));
            Assert.False(AntiDumpManifest.SafePath("../x.lua"));
            Assert.True(AntiDumpManifest.SafePath("client/a.lua"));
        }
        finally { Directory.Delete(root, true); }
    }
}
