using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Logging
{
    public sealed class DetectionLogConfig
    {
        public bool Enabled { get; set; } = true;
        public int KeepDays { get; set; } = 14;
    }

    public sealed class DetectionLog
    {
        private readonly DetectionLogConfig _config;
        private readonly string _dir;
        private readonly object _lock = new object();
        private DateTime _lastPrune = DateTime.MinValue;

        public DetectionLog(DetectionLogConfig config, string dir)
        {
            _config = config;
            _dir = dir;
        }

        public string Directory => _dir;

        public void Write(string playerName, IEnumerable<string> identifiers, Violation v, bool bypass, bool dryRun, bool reported, DateTime now)
        {
            if (!_config.Enabled) return;
            var line = MiniJson.Serialize(new Dictionary<string, object?>
            {
                ["at"] = now.ToString("o"), ["player"] = v.Player, ["name"] = playerName,
                ["license"] = identifiers.FirstOrDefault(i => i.StartsWith("license:", StringComparison.Ordinal)),
                ["code"] = v.Code, ["source"] = v.Source.ToString().ToLowerInvariant(), ["severity"] = v.Severity,
                ["score"] = Math.Round(v.ScoreAfter, 1), ["action"] = v.Action.ToString().ToLowerInvariant(),
                ["bypass"] = bypass, ["dryRun"] = dryRun, ["reported"] = reported, ["evidence"] = v.Evidence,
            });
            lock (_lock)
            {
                System.IO.Directory.CreateDirectory(_dir);
                File.AppendAllText(Path.Combine(_dir, "detections-" + now.ToString("yyyy-MM-dd") + ".jsonl"), line + "\n");
                if (now - _lastPrune > TimeSpan.FromHours(6)) Prune(now);
            }
        }

        private void Prune(DateTime now)
        {
            _lastPrune = now;
            foreach (var f in System.IO.Directory.GetFiles(_dir, "detections-*.jsonl"))
            {
                var name = Path.GetFileNameWithoutExtension(f).Substring("detections-".Length);
                if (DateTime.TryParse(name, out var day) && now.Date - day.Date > TimeSpan.FromDays(_config.KeepDays)) File.Delete(f);
            }
        }
    }
}
