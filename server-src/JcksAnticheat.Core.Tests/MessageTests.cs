using System.Collections.Generic;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Messages;
using Xunit;

public class MessageTests
{
    [Fact]
    public void PlaceholdersAreFilled()
    {
        var m = new MessageSettings { AppealUrl = "https://discord.gg/example" };
        var text = m.Format(m.Banned, new Dictionary<string, string?> { ["reason"] = "Automated: PLY_GODMODE_FLAG", ["id"] = "abc123", ["expires"] = "permanent" });
        Assert.Equal("[JCKS Anticheat] You are banned. Reason: Automated: PLY_GODMODE_FLAG | Ban ID: abc123 | Expires: permanent | Appeal: https://discord.gg/example", text);
    }

    [Fact]
    public void AppealIsHiddenWhenEmptyAndUnknownPlaceholdersStay()
    {
        var m = new MessageSettings();
        Assert.Equal("x  {weird}", m.Format("x {appeal} {weird}", new Dictionary<string, string?>()));
        Assert.DoesNotContain("\n", m.Format("a\nb", new Dictionary<string, string?>()));
    }

    [Fact]
    public void MessagesRoundTripAndValidate()
    {
        var cfg = AnticheatConfig.Parse("{\"messages\":{\"kick\":\"Bye {name}\",\"appealUrl\":\"https://x.y\"}}");
        Assert.Equal("Bye {name}", cfg.Messages.Kick);
        var again = AnticheatConfig.Parse(JcksAnticheat.Core.Json.MiniJson.Serialize(cfg.ToJson()));
        Assert.Equal("https://x.y", again.Messages.AppealUrl);
        cfg.Messages.Ban = "";
        Assert.Contains(cfg.Validate(), e => e.Contains("messages"));
    }
}

public class BanLinkTests
{
    [Fact]
    public void NewIdentifiersJoinTheBanButNotIpsOrOtherBans()
    {
        var path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "jac-bans-" + System.Guid.NewGuid().ToString("N") + ".json");
        try
        {
            var store = new JcksAnticheat.Core.Bans.BanStore(path);
            var ban = store.Add(new JcksAnticheat.Core.Bans.Ban { Name = "a", Identifiers = new List<string> { "license:old", "token:hw1" } });
            var other = store.Add(new JcksAnticheat.Core.Bans.Ban { Name = "b", Identifiers = new List<string> { "discord:taken" } });
            var connecting = new[] { "license:new", "token:hw1", "ip:1.2.3.4", "discord:taken", "discord:fresh" };
            Assert.Same(ban, store.Find(connecting));
            var added = store.Link(ban, connecting);
            Assert.Equal(new[] { "license:new", "discord:fresh" }, added);
            Assert.Same(ban, store.Find(new[] { "license:new" }));
            Assert.Same(other, store.Find(new[] { "discord:taken" }));
            Assert.Null(store.Find(new[] { "ip:1.2.3.4" }));
            Assert.Empty(store.Link(ban, connecting));
            var reloaded = new JcksAnticheat.Core.Bans.BanStore(path);
            Assert.NotNull(reloaded.Find(new[] { "discord:fresh" }));
        }
        finally { System.IO.File.Delete(path); }
    }
}
