using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Vision
{
    public enum VisionVerdictKind { Clean, Suspicious, Cheat, Error }

    public sealed class VisionFinding
    {
        public string Type { get; set; } = "other";
        public string Description { get; set; } = "";
    }

    public sealed class VisionVerdict : IJsonWritable
    {
        public VisionVerdictKind Verdict { get; set; }
        public double Confidence { get; set; }
        public string Summary { get; set; } = "";
        public List<VisionFinding> Findings { get; set; } = new List<VisionFinding>();
        public string Model { get; set; } = "";
        public string? Error { get; set; }

        public object ToJson() => new Dictionary<string, object?>
        {
            ["verdict"] = Verdict.ToString().ToLowerInvariant(),
            ["confidence"] = Confidence,
            ["summary"] = Summary,
            ["findings"] = Findings.Select(f => new Dictionary<string, object?> { ["type"] = f.Type, ["description"] = f.Description }).ToList(),
            ["model"] = Model,
            ["error"] = Error,
        };
    }

    public sealed class AIVisionEvaluator : IDisposable
    {
        public const string AnthropicVersion = "2026-10-21";
        public const string FallbackBeta = "server-side-fallback-2026-07-01";

        internal const string SystemPrompt =
            "You review screenshots from a GTA V roleplay server (FiveM) for an anti-cheat team. " +
            "Decide whether the frame shows a cheat overlay drawn on top of the game. Cheat overlays include: " +
            "ESP boxes or skeletons drawn around players or peds, often through walls; snap lines from the screen " +
            "edge or centre to players; floating text with player names, distances or health that the game " +
            "doesn't normally draw; an aimbot FOV circle around the crosshair; and injected mod-menu windows " +
            "(lists of options like 'Godmode', 'Noclip', 'Spawn vehicle', 'Aimbot', 'Triggerbot', often with a " +
            "custom header or watermark). " +
            "Do not flag normal game or server UI: the minimap, health/armour bars, the weapon wheel, phone, " +
            "inventory, chat, scoreboard, HUD speedometers, job markers, the game's own crosshair or reticle, " +
            "server nametags above heads, notifications, or loading screens. If the image is black, blurred or " +
            "you can't tell, answer 'clean' with low confidence. Base the verdict only on what is visible, " +
            "and put the specific visual evidence in the findings.";

        internal static readonly object VerdictSchema = new Dictionary<string, object?>
        {
            ["type"] = "object",
            ["additionalProperties"] = false,
            ["required"] = new List<object?> { "verdict", "confidence", "summary", "findings" },
            ["properties"] = new Dictionary<string, object?>
            {
                ["verdict"] = new Dictionary<string, object?> { ["type"] = "string", ["enum"] = new List<object?> { "clean", "suspicious", "cheat" } },
                ["confidence"] = new Dictionary<string, object?> { ["type"] = "number", ["description"] = "0.0 to 1.0" },
                ["summary"] = new Dictionary<string, object?> { ["type"] = "string", ["description"] = "One sentence for a human moderator." },
                ["findings"] = new Dictionary<string, object?>
                {
                    ["type"] = "array",
                    ["items"] = new Dictionary<string, object?>
                    {
                        ["type"] = "object",
                        ["additionalProperties"] = false,
                        ["required"] = new List<object?> { "type", "description" },
                        ["properties"] = new Dictionary<string, object?>
                        {
                            ["type"] = new Dictionary<string, object?>
                            {
                                ["type"] = "string",
                                ["enum"] = new List<object?> { "esp_box", "esp_line", "esp_text", "fov_circle", "mod_menu", "other" },
                            },
                            ["description"] = new Dictionary<string, object?> { ["type"] = "string" },
                        },
                    },
                },
            },
        };

        private readonly VisionConfig _config;
        private readonly HttpClient _http;
        private readonly Func<string?> _apiKey;

        public AIVisionEvaluator(VisionConfig config, HttpMessageHandler? handler = null, Func<string?>? apiKey = null)
        {
            _config = config;
            _http = handler != null ? new HttpClient(handler) : new HttpClient();
            _http.Timeout = TimeSpan.FromSeconds(120);
            _apiKey = apiKey ?? (() => Environment.GetEnvironmentVariable(config.ApiKeyEnv));
        }

        public bool IsConfigured => _config.Enabled && !string.IsNullOrEmpty(_apiKey());

        public async Task<VisionVerdict> EvaluateAsync(byte[] jpeg, string context, CancellationToken ct = default)
        {
            var key = _apiKey();
            if (string.IsNullOrEmpty(key))
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = $"env {_config.ApiKeyEnv} not set", Model = _config.Model };
            if (jpeg.Length > _config.MaxImageBytes)
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = "image too large", Model = _config.Model };

            try
            {
                bool anthropic = string.Equals(_config.Provider, "anthropic", StringComparison.OrdinalIgnoreCase);
                using var request = anthropic ? BuildAnthropicRequest(key!, jpeg, context) : BuildOpenAiRequest(key!, jpeg, context);
                using var response = await _http.SendAsync(request, ct).ConfigureAwait(false);
                var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!response.IsSuccessStatusCode)
                    return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = $"HTTP {(int)response.StatusCode}: {Truncate(body, 300)}", Model = _config.Model };
                return anthropic ? ParseAnthropic(body) : ParseOpenAi(body);
            }
            catch (Exception ex) when (!(ex is OperationCanceledException) || !ct.IsCancellationRequested)
            {
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = ex.GetType().Name + ": " + ex.Message, Model = _config.Model };
            }
        }

        internal HttpRequestMessage BuildAnthropicRequest(string key, byte[] jpeg, string context)
        {
            var body = new Dictionary<string, object?>
            {
                ["model"] = _config.Model,
                ["max_tokens"] = 16000,
                ["system"] = SystemPrompt,
                ["messages"] = new List<object?>
                {
                    new Dictionary<string, object?>
                    {
                        ["role"] = "user",
                        ["content"] = new List<object?>
                        {
                            new Dictionary<string, object?>
                            {
                                ["type"] = "image",
                                ["source"] = new Dictionary<string, object?>
                                {
                                    ["type"] = "base64", ["media_type"] = "image/jpeg", ["data"] = Convert.ToBase64String(jpeg),
                                },
                            },
                            new Dictionary<string, object?> { ["type"] = "text", ["text"] = "Why this frame was captured: " + context },
                        },
                    },
                },
                ["output_config"] = new Dictionary<string, object?>
                {
                    ["effort"] = _config.Effort,
                    ["format"] = new Dictionary<string, object?> { ["type"] = "json_schema", ["schema"] = VerdictSchema },
                },
                ["fallbacks"] = "default",
            };

            var req = new HttpRequestMessage(HttpMethod.Post, _config.Endpoint)
            {
                Content = new StringContent(MiniJson.Serialize(body), Encoding.UTF8, "application/json"),
            };
            req.Headers.Add("x-api-key", key);
            req.Headers.Add("anthropic-version", AnthropicVersion);
            req.Headers.Add("anthropic-beta", FallbackBeta);
            return req;
        }

        internal HttpRequestMessage BuildOpenAiRequest(string key, byte[] jpeg, string context)
        {
            var body = new Dictionary<string, object?>
            {
                ["model"] = _config.Model,
                ["response_format"] = new Dictionary<string, object?> { ["type"] = "json_object" },
                ["messages"] = new List<object?>
                {
                    new Dictionary<string, object?>
                    {
                        ["role"] = "system",
                        ["content"] = SystemPrompt + " Respond with JSON only: {\"verdict\": \"clean|suspicious|cheat\", \"confidence\": 0-1, " +
                                      "\"summary\": string, \"findings\": [{\"type\": \"esp_box|esp_line|esp_text|fov_circle|mod_menu|other\", \"description\": string}]}",
                    },
                    new Dictionary<string, object?>
                    {
                        ["role"] = "user",
                        ["content"] = new List<object?>
                        {
                            new Dictionary<string, object?> { ["type"] = "text", ["text"] = "Why this frame was captured: " + context },
                            new Dictionary<string, object?>
                            {
                                ["type"] = "image_url",
                                ["image_url"] = new Dictionary<string, object?> { ["url"] = "data:image/jpeg;base64," + Convert.ToBase64String(jpeg) },
                            },
                        },
                    },
                },
            };
            var req = new HttpRequestMessage(HttpMethod.Post, _config.Endpoint)
            {
                Content = new StringContent(MiniJson.Serialize(body), Encoding.UTF8, "application/json"),
            };
            req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + key);
            return req;
        }

        internal VisionVerdict ParseAnthropic(string body)
        {
            var root = MiniJson.Parse(body, 8 << 20) as Dictionary<string, object?>;
            var model = root.Str("model") ?? _config.Model;
            var stop = root.Str("stop_reason");
            if (stop == "refusal")
            {
                var category = root.Obj("stop_details").Str("category") ?? "unknown";
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = "model declined (refusal: " + category + ")", Model = model };
            }
            if (stop == "max_tokens")
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = "response truncated (max_tokens)", Model = model };

            var text = string.Concat((root.Arr("content") ?? new List<object?>())
                .OfType<Dictionary<string, object?>>()
                .Where(b => b.Str("type") == "text")
                .Select(b => b.Str("text") ?? ""));
            var verdict = ParseVerdictJson(text);
            verdict.Model = model;
            return verdict;
        }

        internal VisionVerdict ParseOpenAi(string body)
        {
            var root = MiniJson.Parse(body, 8 << 20) as Dictionary<string, object?>;
            var first = root.Arr("choices")?.FirstOrDefault();
            var content = (first.Obj("message")).Str("content") ?? "";
            var verdict = ParseVerdictJson(content);
            verdict.Model = root.Str("model") ?? _config.Model;
            return verdict;
        }

        internal static VisionVerdict ParseVerdictJson(string text)
        {
            text = text.Trim();
            if (text.StartsWith("```", StringComparison.Ordinal))
            {
                int start = text.IndexOf('{'); int end = text.LastIndexOf('}');
                if (start >= 0 && end > start) text = text.Substring(start, end - start + 1);
            }
            if (!MiniJson.TryParse(text, out var parsed) || !(parsed is Dictionary<string, object?> o))
                return new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = "unparseable verdict: " + Truncate(text, 200) };

            var v = new VisionVerdict
            {
                Verdict = (o.Str("verdict") ?? "").ToLowerInvariant() switch
                {
                    "clean" => VisionVerdictKind.Clean,
                    "suspicious" => VisionVerdictKind.Suspicious,
                    "cheat" => VisionVerdictKind.Cheat,
                    _ => VisionVerdictKind.Error,
                },
                Confidence = Math.Max(0, Math.Min(1, o.Num("confidence") ?? 0)),
                Summary = o.Str("summary") ?? "",
            };
            foreach (var f in (o.Arr("findings") ?? new List<object?>()).OfType<Dictionary<string, object?>>())
                v.Findings.Add(new VisionFinding { Type = f.Str("type") ?? "other", Description = f.Str("description") ?? "" });
            if (v.Verdict == VisionVerdictKind.Error) v.Error = "unknown verdict value";
            return v;
        }

        private static string Truncate(string s, int n) => s.Length <= n ? s : s.Substring(0, n) + "…";

        public void Dispose() => _http.Dispose();
    }
}
