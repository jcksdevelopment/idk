using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;

namespace JcksAnticheat.Core.Config
{
    public sealed class ConfigHistory
    {
        private readonly string _dir;
        private readonly int _keep;

        public ConfigHistory(string dir, int keep = 20)
        {
            _dir = dir;
            _keep = Math.Max(1, keep);
        }

        public string? Push(string? json, DateTime now)
        {
            if (string.IsNullOrWhiteSpace(json)) return null;
            Directory.CreateDirectory(_dir);
            var latest = Entries().FirstOrDefault();
            if (latest != null && File.ReadAllText(latest) == json) return latest;
            var path = Path.Combine(_dir, "config-" + now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture) + ".json");
            File.WriteAllText(path, json);
            foreach (var old in Entries().Skip(_keep)) File.Delete(old);
            return path;
        }

        public List<string> Entries()
        {
            if (!Directory.Exists(_dir)) return new List<string>();
            return Directory.GetFiles(_dir, "config-*.json").OrderByDescending(f => Path.GetFileName(f), StringComparer.Ordinal).ToList();
        }

        public string? Read(int index)
        {
            var list = Entries();
            return index >= 1 && index <= list.Count ? File.ReadAllText(list[index - 1]) : null;
        }

        public static string Label(string path)
        {
            var name = Path.GetFileNameWithoutExtension(path).Substring("config-".Length);
            return DateTime.TryParseExact(name, "yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var t)
                ? t.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) + " UTC" : name;
        }
    }
}
