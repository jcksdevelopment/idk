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
