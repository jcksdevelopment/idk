using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Bans
{
    public sealed class Ban : IJsonWritable
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N").Substring(0, 12);
        public string Name { get; set; } = "";
        public List<string> Identifiers { get; set; } = new List<string>();
        public string Reason { get; set; } = "";
        public string Code { get; set; } = "";
        public string BannedBy { get; set; } = "jcks_anticheat";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? ExpiresAt { get; set; }

        public bool IsActive(DateTime now) => ExpiresAt == null || ExpiresAt > now;

        public object ToJson() => new Dictionary<string, object?>
        {
            ["id"] = Id, ["name"] = Name, ["identifiers"] = Identifiers, ["reason"] = Reason, ["code"] = Code,
            ["bannedBy"] = BannedBy, ["createdAt"] = CreatedAt, ["expiresAt"] = ExpiresAt,
        };

        public static Ban? FromJson(object? o)
        {
            if (!(o is Dictionary<string, object?> d)) return null;
            var ban = new Ban
            {
                Id = d.Str("id") ?? Guid.NewGuid().ToString("N").Substring(0, 12),
                Name = d.Str("name") ?? "",
                Reason = d.Str("reason") ?? "",
                Code = d.Str("code") ?? "",
                BannedBy = d.Str("bannedBy") ?? "jcks_anticheat",
                Identifiers = (d.Arr("identifiers") ?? new List<object?>()).OfType<string>().ToList(),
            };
            if (DateTime.TryParse(d.Str("createdAt"), null, System.Globalization.DateTimeStyles.RoundtripKind, out var c)) ban.CreatedAt = c;
            if (DateTime.TryParse(d.Str("expiresAt"), null, System.Globalization.DateTimeStyles.RoundtripKind, out var e)) ban.ExpiresAt = e;
            return ban;
        }
    }

    public sealed class BanStore
    {
        private readonly string _path;
        private readonly ConcurrentDictionary<string, Ban> _byId = new ConcurrentDictionary<string, Ban>();
        private readonly ConcurrentDictionary<string, string> _byIdentifier = new ConcurrentDictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private readonly object _writeLock = new object();

        public BanStore(string path)
        {
            _path = path;
            Load();
        }

        public IReadOnlyCollection<Ban> All => _byId.Values.ToList();

        public Ban? Find(IEnumerable<string> identifiers, DateTime? now = null)
        {
            var t = now ?? DateTime.UtcNow;
            foreach (var id in identifiers)
            {
                if (IsIgnoredIdentifier(id)) continue;
                if (_byIdentifier.TryGetValue(id, out var banId) && _byId.TryGetValue(banId, out var ban) && ban.IsActive(t))
                    return ban;
            }
            return null;
        }

        public Ban Add(Ban ban)
        {
            ban.Identifiers = ban.Identifiers.Where(i => !IsIgnoredIdentifier(i)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            _byId[ban.Id] = ban;
            foreach (var id in ban.Identifiers) _byIdentifier[id] = ban.Id;
            Save();
            return ban;
        }

        public List<string> Link(Ban ban, IEnumerable<string> identifiers, int maxIdentifiers = 200)
        {
            var added = new List<string>();
            foreach (var id in identifiers)
            {
                if (string.IsNullOrWhiteSpace(id) || IsIgnoredIdentifier(id) || ban.Identifiers.Count >= maxIdentifiers) continue;
                if (ban.Identifiers.Contains(id, StringComparer.OrdinalIgnoreCase)) continue;
                if (_byIdentifier.TryGetValue(id, out var other) && other != ban.Id && _byId.TryGetValue(other, out var o) && o.IsActive(DateTime.UtcNow)) continue;
                ban.Identifiers.Add(id);
                _byIdentifier[id] = ban.Id;
                added.Add(id);
            }
            if (added.Count > 0) Save();
            return added;
        }

        public bool Remove(string banId)
        {
            if (!_byId.TryRemove(banId, out var ban)) return false;
            foreach (var id in ban.Identifiers)
                if (_byIdentifier.TryGetValue(id, out var owner) && owner == banId) _byIdentifier.TryRemove(id, out _);
            Save();
            return true;
        }

        private static bool IsIgnoredIdentifier(string id) => id.StartsWith("ip:", StringComparison.OrdinalIgnoreCase);

        private void Load()
        {
            if (!File.Exists(_path)) return;
            if (!(MiniJson.Parse(File.ReadAllText(_path), 64 << 20) is List<object?> list)) return;
            foreach (var item in list)
            {
                var ban = Ban.FromJson(item);
                if (ban == null) continue;
                _byId[ban.Id] = ban;
                foreach (var id in ban.Identifiers) _byIdentifier[id] = ban.Id;
            }
        }

        private void Save()
        {
            lock (_writeLock)
            {
                var dir = Path.GetDirectoryName(_path);
                if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
                var tmp = _path + ".tmp";
                File.WriteAllText(tmp, MiniJson.Serialize(_byId.Values.OrderBy(b => b.CreatedAt).ToList()));
                if (File.Exists(_path)) File.Delete(_path);
                File.Move(tmp, _path);
            }
        }
    }
}
