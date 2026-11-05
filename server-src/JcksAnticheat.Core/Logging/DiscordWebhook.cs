using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Logging
{
    public sealed class DiscordConfig
    {
        public bool Enabled { get; set; }
        public string WebhookEnv { get; set; } = "JCKS_AC_DISCORD_WEBHOOK";
        public string MinAction { get; set; } = "kick";
        public string Username { get; set; } = "JCKS Anticheat";
    }

    public sealed class DiscordWebhook : IDisposable
    {
        private readonly DiscordConfig _config;
        private readonly HttpClient _http;
        private readonly Func<string?> _url;
        private readonly ConcurrentQueue<Dictionary<string, object?>> _queue = new ConcurrentQueue<Dictionary<string, object?>>();
        private int _sending;

        public string? LastError { get; private set; }

        public DiscordWebhook(DiscordConfig config, HttpMessageHandler? handler = null, Func<string?>? url = null)
        {
            _config = config;
            _http = handler != null ? new HttpClient(handler) : new HttpClient();
            _http.Timeout = TimeSpan.FromSeconds(10);
            _url = url ?? (() => Environment.GetEnvironmentVariable(config.WebhookEnv));
        }

        public bool Enabled => _config.Enabled && !string.IsNullOrEmpty(_url());

        public static int Rank(string action) => action switch
        {
            "log" => 0, "screenshot" => 1, "kick" => 2, "ban" => 3, _ => 2,
        };

        public static int Rank(EnforcementAction action) => action switch
        {
            EnforcementAction.Ban => 3, EnforcementAction.Kick => 2, EnforcementAction.Screenshot => 1, _ => 0,
        };

        public void Detection(string playerName, int playerId, Violation v, bool dryRun)
        {
            if (!Enabled || (Rank(v.Action) < Rank(_config.MinAction) && v.Action != EnforcementAction.Ban)) return;
            var fields = new List<object?>
            {
                Field("Player", $"{playerName} (#{playerId})", true),
                Field("Action", v.Action.ToString().ToLowerInvariant() + (dryRun ? " (dry run)" : ""), true),
                Field("Score", $"{v.ScoreAfter:F0} (+{v.Severity})", true),
                Field("Source", v.Source.ToString().ToLowerInvariant(), true),
            };
            if (v.Evidence.Count > 0) fields.Add(Field("Evidence", "```" + Trim(MiniJson.Serialize(v.Evidence), 990) + "```", false));
            Enqueue(v.Code, null, v.Action == EnforcementAction.Ban ? 0xDC2626 : v.Action == EnforcementAction.Kick ? 0xF59E0B : 0x64748B, fields);
        }

        public void Ban(string playerName, string banId, string reason, string actor, DateTime? expires)
        {
            if (!Enabled) return;
            Enqueue("Player banned", null, 0xDC2626, new List<object?>
            {
                Field("Player", playerName, true), Field("Ban ID", banId, true), Field("By", actor, true),
                Field("Expires", expires.HasValue ? expires.Value.ToString("yyyy-MM-dd HH:mm") + " UTC" : "permanent", true),
                Field("Reason", reason, false),
            });
        }

        public void Notice(string title, string description)
        {
            if (Enabled) Enqueue(title, description, 0x64748B, new List<object?>());
        }

        private void Enqueue(string title, string? description, int color, List<object?> fields)
        {
            if (_queue.Count > 500) return;
            var embed = new Dictionary<string, object?>
            {
                ["title"] = Trim(title, 256),
                ["color"] = color,
                ["fields"] = fields,
                ["timestamp"] = DateTime.UtcNow,
            };
            if (description != null) embed["description"] = Trim(description, 2000);
            _queue.Enqueue(embed);
        }

        public Task FlushAsync()
        {
            if (_queue.IsEmpty || !Enabled || Interlocked.Exchange(ref _sending, 1) == 1) return Task.CompletedTask;
            return Task.Run(async () =>
            {
                var batch = new List<object?>();
                try
                {
                    while (batch.Count < 10 && _queue.TryDequeue(out var e)) batch.Add(e);
                    var body = MiniJson.Serialize(new Dictionary<string, object?> { ["username"] = _config.Username, ["embeds"] = batch });
                    using var res = await _http.PostAsync(_url(), new StringContent(body, Encoding.UTF8, "application/json")).ConfigureAwait(false);
                    LastError = res.IsSuccessStatusCode ? null : "discord HTTP " + (int)res.StatusCode;
                }
                catch (Exception ex) { LastError = "discord: " + ex.Message; }
                finally { Interlocked.Exchange(ref _sending, 0); }
            });
        }

        private static Dictionary<string, object?> Field(string name, string value, bool inline) => new Dictionary<string, object?>
        {
            ["name"] = Trim(name, 256), ["value"] = string.IsNullOrEmpty(value) ? "-" : Trim(value, 1024), ["inline"] = inline,
        };

        private static string Trim(string s, int max) => s.Length <= max ? s : s.Substring(0, max - 1) + "…";

        public void Dispose() => _http.Dispose();
    }
}
