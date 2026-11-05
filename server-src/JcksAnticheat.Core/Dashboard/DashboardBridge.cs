using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Dashboard
{
    public sealed class DashboardCommand
    {
        public string Id { get; set; } = "";
        public string Type { get; set; } = "";
        public int Player { get; set; }
        public string? BanId { get; set; }
        public string? Reason { get; set; }
        public double? DurationHours { get; set; }
        public string? Actor { get; set; }
        public List<string> Identifiers { get; set; } = new List<string>();
        public string? Name { get; set; }
        public string? Config { get; set; }
    }

    public sealed class DashboardBridge : IDisposable
    {
        private readonly DashboardConfig _config;
        private readonly HttpClient _http;
        private readonly ConcurrentQueue<Dictionary<string, object?>> _outbox = new ConcurrentQueue<Dictionary<string, object?>>();
        private readonly ConcurrentQueue<DashboardCommand> _inbox = new ConcurrentQueue<DashboardCommand>();
        private readonly string? _secret;
        private int _flushing;
        private int _polling;

        public int MaxQueued { get; set; } = 5000;
        public string? LastError { get; private set; }

        public DashboardBridge(DashboardConfig config, HttpMessageHandler? handler = null, string? secret = null)
        {
            _config = config;
            _http = handler != null ? new HttpClient(handler) : new HttpClient();
            _http.Timeout = TimeSpan.FromSeconds(10);
            _secret = secret ?? Environment.GetEnvironmentVariable(config.SecretEnv);
        }

        public bool Enabled => _config.Enabled && !string.IsNullOrEmpty(_secret);

        public void Enqueue(string type, object payload)
        {
            if (!Enabled) return;
            if (_outbox.Count >= MaxQueued) _outbox.TryDequeue(out _);
            _outbox.Enqueue(new Dictionary<string, object?> { ["type"] = type, ["at"] = DateTime.UtcNow, ["data"] = payload });
        }

        public bool TryDequeueCommand(out DashboardCommand? command)
        {
            var ok = _inbox.TryDequeue(out var c);
            command = c;
            return ok;
        }

        public Task FlushAsync()
        {
            if (!Enabled || _outbox.IsEmpty || System.Threading.Interlocked.Exchange(ref _flushing, 1) == 1) return Task.CompletedTask;
            return Task.Run(async () =>
            {
                var batch = new List<Dictionary<string, object?>>();
                try
                {
                    while (batch.Count < 500 && _outbox.TryDequeue(out var e)) batch.Add(e);
                    var body = MiniJson.Serialize(new Dictionary<string, object?> { ["serverId"] = _config.ServerId, ["events"] = batch });
                    using var req = new HttpRequestMessage(HttpMethod.Post, _config.Url + "/api/ingest")
                    {
                        Content = new StringContent(body, Encoding.UTF8, "application/json"),
                    };
                    req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + _secret);
                    using var res = await _http.SendAsync(req).ConfigureAwait(false);
                    if (!res.IsSuccessStatusCode)
                    {
                        LastError = "ingest HTTP " + (int)res.StatusCode;
                        Requeue(batch);
                    }
                    else LastError = null;
                }
                catch (Exception ex)
                {
                    LastError = "ingest: " + ex.Message;
                    Requeue(batch);
                }
                finally { System.Threading.Interlocked.Exchange(ref _flushing, 0); }
            });
        }

        public Task PollAsync()
        {
            if (!Enabled || System.Threading.Interlocked.Exchange(ref _polling, 1) == 1) return Task.CompletedTask;
            return Task.Run(async () =>
            {
                try
                {
                    using var req = new HttpRequestMessage(HttpMethod.Get, _config.Url + "/api/server/commands?serverId=" + Uri.EscapeDataString(_config.ServerId));
                    req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + _secret);
                    using var res = await _http.SendAsync(req).ConfigureAwait(false);
                    if (!res.IsSuccessStatusCode) { LastError = "commands HTTP " + (int)res.StatusCode; return; }
                    var root = MiniJson.Parse(await res.Content.ReadAsStringAsync().ConfigureAwait(false));
                    foreach (var c in (root.Arr("commands") ?? new List<object?>()).OfType<Dictionary<string, object?>>())
                    {
                        _inbox.Enqueue(new DashboardCommand
                        {
                            Id = c.Str("id") ?? "",
                            Type = c.Str("type") ?? "",
                            Player = (int)(c.Num("player") ?? 0),
                            BanId = c.Str("banId"),
                            Reason = c.Str("reason"),
                            DurationHours = c.Num("durationHours"),
                            Actor = c.Str("actor"),
                            Identifiers = (c.Arr("identifiers") ?? new List<object?>()).OfType<string>().ToList(),
                            Name = c.Str("name"),
                            Config = c.Str("config"),
                        });
                    }
                }
                catch (Exception ex) { LastError = "commands: " + ex.Message; }
                finally { System.Threading.Interlocked.Exchange(ref _polling, 0); }
            });
        }

        private void Requeue(List<Dictionary<string, object?>> batch)
        {
            foreach (var e in batch)
                if (_outbox.Count < MaxQueued) _outbox.Enqueue(e);
        }

        public void Dispose() => _http.Dispose();
    }
}
