using System.Net;
using System.Text;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Vision;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class VisionTests
{
    private sealed class FakeHandler : HttpMessageHandler
    {
        private readonly string _response;
        private readonly HttpStatusCode _status;
        public HttpRequestMessage? Request;
        public string? Body;
        public FakeHandler(string response, HttpStatusCode status = HttpStatusCode.OK) { _response = response; _status = status; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Request = request;
            Body = await request.Content!.ReadAsStringAsync(ct);
            return new HttpResponseMessage(_status) { Content = new StringContent(_response, Encoding.UTF8, "application/json") };
        }
    }

    private static readonly byte[] Jpeg = { 0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3 };

    [Fact]
    public async Task AnthropicRequestUsesStructuredOutputAndParsesVerdict()
    {
        const string response = """
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5-5","stop_reason":"end_turn",
         "content":[{"type":"thinking","thinking":""},
                    {"type":"text","text":"{\"verdict\":\"cheat\",\"confidence\":0.93,\"summary\":\"Mod menu open on the left.\",\"findings\":[{\"type\":\"mod_menu\",\"description\":\"List with Godmode and Noclip toggles\"}]}"}]}
        """;
        var handler = new FakeHandler(response);
        var eval = new AIVisionEvaluator(new VisionConfig { Enabled = true }, handler, () => "test-key");

        var verdict = await eval.EvaluateAsync(Jpeg, "MOV_TELEPORT (score 60)");

        Assert.Equal(VisionVerdictKind.Cheat, verdict.Verdict);
        Assert.Equal(0.93, verdict.Confidence, 3);
        Assert.Equal("mod_menu", Assert.Single(verdict.Findings).Type);

        Assert.Equal("https://api.anthropic.com/v1/messages", handler.Request!.RequestUri!.ToString());
        Assert.Equal("test-key", handler.Request.Headers.GetValues("x-api-key").Single());
        Assert.Equal(AIVisionEvaluator.AnthropicVersion, handler.Request.Headers.GetValues("anthropic-version").Single());
        Assert.Equal(AIVisionEvaluator.FallbackBeta, handler.Request.Headers.GetValues("anthropic-beta").Single());

        var body = MiniJson.Parse(handler.Body!);
        Assert.Equal("claude-opus-5-5", body.Str("model"));
        Assert.Equal("json_schema", body.Obj("output_config").Obj("format").Str("type"));
        Assert.Equal("default", body.Str("fallbacks"));
        var content = (List<object?>)((Dictionary<string, object?>)body.Arr("messages")![0]!)["content"]!;
        Assert.Equal("image", content[0].Str("type"));
        Assert.Equal(Convert.ToBase64String(Jpeg), content[0].Obj("source").Str("data"));
    }

    [Fact]
    public async Task RefusalBecomesErrorVerdict()
    {
        const string response = """{"model":"claude-opus-5-5","stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber"},"content":[]}""";
        var eval = new AIVisionEvaluator(new VisionConfig { Enabled = true }, new FakeHandler(response), () => "k");
        var verdict = await eval.EvaluateAsync(Jpeg, "x");
        Assert.Equal(VisionVerdictKind.Error, verdict.Verdict);
        Assert.Contains("cyber", verdict.Error);
    }

    [Fact]
    public async Task HttpErrorsAndMissingKeyAreReported()
    {
        var failing = new AIVisionEvaluator(new VisionConfig { Enabled = true }, new FakeHandler("{\"error\":{}}", HttpStatusCode.TooManyRequests), () => "k");
        Assert.Contains("429", (await failing.EvaluateAsync(Jpeg, "x")).Error);

        var noKey = new AIVisionEvaluator(new VisionConfig { Enabled = true }, new FakeHandler("{}"), () => null);
        Assert.False(noKey.IsConfigured);
        Assert.Equal(VisionVerdictKind.Error, (await noKey.EvaluateAsync(Jpeg, "x")).Verdict);
    }

    [Fact]
    public async Task OpenAiCompatibleProviderParsesFencedJson()
    {
        const string response = """{"model":"deepseek-vl","choices":[{"message":{"content":"```json\n{\"verdict\":\"clean\",\"confidence\":0.2,\"summary\":\"Normal HUD\",\"findings\":[]}\n```"}}]}""";
        var handler = new FakeHandler(response);
        var cfg = new VisionConfig { Enabled = true, Provider = "openai-compatible", Endpoint = "https://api.example.com/v1/chat/completions", Model = "deepseek-vl" };
        var verdict = await new AIVisionEvaluator(cfg, handler, () => "k").EvaluateAsync(Jpeg, "x");
        Assert.Equal(VisionVerdictKind.Clean, verdict.Verdict);
        Assert.Equal("Bearer k", handler.Request!.Headers.GetValues("Authorization").Single());
    }

    [Fact]
    public void ScreenshotChunksReassembleAndUnknownIdsAreDropped()
    {
        var asm = new ScreenshotAssembler();
        var b64 = Convert.ToBase64String(Enumerable.Range(0, 5000).Select(i => (byte)i).ToArray());
        var id = asm.Begin(1, "test");
        var parts = Enumerable.Range(0, 3).Select(i => b64.Substring(i * b64.Length / 3, (i == 2 ? b64.Length : (i + 1) * b64.Length / 3) - i * b64.Length / 3)).ToList();

        Assert.Equal(ScreenshotAssembler.ChunkResult.Unknown, asm.AddChunk(1, "forged", 1, 3, parts[0], out _));
        Assert.Equal(ScreenshotAssembler.ChunkResult.Unknown, asm.AddChunk(2, id, 1, 3, parts[0], out _)); // wrong player
        Assert.Equal(ScreenshotAssembler.ChunkResult.Accepted, asm.AddChunk(1, id, 3, 3, parts[2], out _));
        Assert.Equal(ScreenshotAssembler.ChunkResult.Accepted, asm.AddChunk(1, id, 1, 3, parts[0], out _));
        Assert.Equal(ScreenshotAssembler.ChunkResult.Complete, asm.AddChunk(1, id, 2, 3, parts[1], out var done));
        Assert.Equal(5000, done!.Jpeg.Length);
        Assert.False(asm.IsPending(1));
    }

    [Fact]
    public void RetentionKeepsNewestFiles()
    {
        var dir = Path.Combine(Path.GetTempPath(), "jac-ret-" + Guid.NewGuid());
        Directory.CreateDirectory(dir);
        try
        {
            for (int i = 0; i < 5; i++)
            {
                var f = Path.Combine(dir, $"{i}.jpg");
                File.WriteAllBytes(f, new byte[] { 1 });
                File.SetLastWriteTimeUtc(f, DateTime.UtcNow.AddMinutes(i));
            }
            Assert.Equal(3, CaptureRetention.Enforce(dir, 2));
            Assert.Equal(new[] { "3.jpg", "4.jpg" }, Directory.GetFiles(dir).Select(Path.GetFileName).OrderBy(x => x));
        }
        finally { Directory.Delete(dir, true); }
    }
}
