using System.Net;
using System.Text;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Logging;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class DiscordTests
{
    private sealed class Capture : HttpMessageHandler
    {
        public readonly List<string> Bodies = new();
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage r, CancellationToken ct)
        {
            Bodies.Add(await r.Content!.ReadAsStringAsync(ct));
            return new HttpResponseMessage(HttpStatusCode.NoContent);
        }
    }

    private static Violation V(EnforcementAction a)
    {
        var v = new Violation(3, "MOV_TELEPORT", ViolationSource.Server, new Dictionary<string, object?> { ["dist"] = 1234.5 });
        typeof(Violation).GetProperty("Action")!.SetValue(v, a);
        return v;
    }

    [Fact]
    public async Task PostsEmbedsAtOrAboveMinActionAndAlwaysBans()
    {
        var h = new Capture();
        var d = new DiscordWebhook(new DiscordConfig { Enabled = true, MinAction = "kick" }, h, () => "https://discord.test/hook");
        d.Detection("Tony", 3, V(EnforcementAction.Log), false);        // below minAction: dropped
        d.Detection("Tony", 3, V(EnforcementAction.Kick), false);
        d.Ban("Tony", "abc123", "Automated: MOV_TELEPORT", "jcks_anticheat", null);
        await d.FlushAsync();
        var body = MiniJson.Parse(Assert.Single(h.Bodies));
        var embeds = body.Arr("embeds")!;
        Assert.Equal(2, embeds.Count);
        Assert.Equal("MOV_TELEPORT", embeds[0].Str("title"));
        Assert.Equal("Player banned", embeds[1].Str("title"));
        Assert.Equal("JCKS Anticheat", body.Str("username"));
    }

    [Fact]
    public async Task DisabledOrMissingUrlSendsNothing()
    {
        var h = new Capture();
        var off = new DiscordWebhook(new DiscordConfig { Enabled = false }, h, () => "https://discord.test/hook");
        off.Ban("x", "1", "r", "a", null);
        await off.FlushAsync();
        var noUrl = new DiscordWebhook(new DiscordConfig { Enabled = true }, h, () => null);
        noUrl.Ban("x", "1", "r", "a", null);
        await noUrl.FlushAsync();
        Assert.Empty(h.Bodies);
    }

    [Fact]
    public async Task BatchesAtMostTenEmbeds()
    {
        var h = new Capture();
        var d = new DiscordWebhook(new DiscordConfig { Enabled = true, MinAction = "log" }, h, () => "https://discord.test/hook");
        for (int i = 0; i < 15; i++) d.Detection("p", 1, V(EnforcementAction.Log), false);
        await d.FlushAsync();
        await d.FlushAsync();
        Assert.Equal(10, MiniJson.Parse(h.Bodies[0]).Arr("embeds")!.Count);
        Assert.Equal(5, MiniJson.Parse(h.Bodies[1]).Arr("embeds")!.Count);
    }
}
