using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using JcksAnticheat.Core.Validation;
using Xunit;

public class VpnCheckTests
{
    private sealed class Fake : HttpMessageHandler
    {
        public int Calls;
        public string? LastUrl;
        public Func<string, HttpResponseMessage> Respond = _ => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("{}") };
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            LastUrl = request.RequestUri!.ToString();
            return Task.FromResult(Respond(LastUrl));
        }
    }

    [Fact]
    public async Task MatchesTheBlockPatternCachesAndFailsOpen()
    {
        var fake = new Fake { Respond = url => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(url.Contains("5.6.7.8") ? "{\"5.6.7.8\": {\"proxy\": \"yes\"}}" : "{\"proxy\": \"no\"}") } };
        var c = new VpnChecker(new VpnConfig { Enabled = true }, fake, () => "secret");
        var now = DateTime.UtcNow;
        Assert.True(await c.IsVpnAsync("5.6.7.8", now));
        Assert.Contains("key=secret", fake.LastUrl);
        Assert.False(await c.IsVpnAsync("8.8.4.4", now));
        Assert.True(await c.IsVpnAsync("5.6.7.8", now.AddHours(1)));
        Assert.Equal(2, fake.Calls);
        Assert.False(await c.IsVpnAsync("192.168.1.20", now));
        Assert.Equal(2, fake.Calls);

        fake.Respond = _ => new HttpResponseMessage(HttpStatusCode.InternalServerError);
        Assert.Null(await c.IsVpnAsync("9.9.9.9", now));
    }

    [Fact]
    public void AllowListAndConfigValidation()
    {
        var c = new VpnChecker(new VpnConfig { Enabled = true, AllowIdentifiers = { "license:abc" } });
        Assert.True(c.Allowed(new[] { "LICENSE:abc", "discord:1" }));
        var cfg = JcksAnticheat.Core.Config.AnticheatConfig.Parse("{}");
        Assert.Empty(cfg.Validate());
        cfg.Vpn.UrlTemplate = "http://example.com/{ip}";
        Assert.Contains(cfg.Validate(), e => e.Contains("vpnCheck"));
        cfg.Vpn.UrlTemplate = "https://example.com/{ip}";
        cfg.Vpn.BlockRegex = "(";
        Assert.Contains(cfg.Validate(), e => e.Contains("blockRegex"));
    }
}
