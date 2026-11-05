using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    public sealed class ExplosionInfo
    {
        public int Source { get; set; }
        public int ExplosionType { get; set; }
        public float DamageScale { get; set; }
        public bool IsInvisible { get; set; }
        public bool IsAudible { get; set; } = true;
        public float CameraShake { get; set; }
        public Vec3 Position { get; set; }
        public int OwnerPlayer { get; set; }
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    public sealed class ExplosionPolicy
    {
        public HashSet<int> Blacklist { get; set; } = new HashSet<int>
        {
            16,
            18,
            26,
            29,
            32,
            35,
            36,
            37,
            41,
        };
        public int MaxPerSecond { get; set; } = 4;
        public int MaxPer10Seconds { get; set; } = 12;
        public float MaxDamageScale { get; set; } = 1.5f;
    }

    public sealed class ExplosionValidator
    {
        public static readonly HashSet<int> WeaponExplosionTypes = new HashSet<int> { 0, 1, 2, 3, 4, 5, 18, 32, 33, 36, 40 };

        private readonly ExplosionPolicy _policy;
        private readonly SlidingCounter _counter = new SlidingCounter();

        public ExplosionValidator(ExplosionPolicy policy) { _policy = policy; }

        public (List<Violation> violations, bool cancel) Evaluate(ExplosionInfo e)
        {
            var found = new List<Violation>();
            var evidence = new Dictionary<string, object?>
            {
                ["type"] = e.ExplosionType, ["scale"] = Math.Round(e.DamageScale, 2), ["pos"] = e.Position.ToString(),
                ["invisible"] = e.IsInvisible, ["audible"] = e.IsAudible,
            };

            if (e.ExplosionType == 18)
                found.Add(new Violation(e.Source, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server, evidence));
            else if (_policy.Blacklist.Contains(e.ExplosionType))
                found.Add(new Violation(e.Source, "WPN_EXPLOSION_BLACKLIST", ViolationSource.Server, evidence));

            if (e.OwnerPlayer > 0 && e.OwnerPlayer != e.Source && WeaponExplosionTypes.Contains(e.ExplosionType))
                found.Add(new Violation(e.Source, "WPN_EXPLOSION_BLAME", ViolationSource.Server, With(evidence, "owner", e.OwnerPlayer)));

            if (e.IsInvisible && !e.IsAudible && e.CameraShake <= 0)
                found.Add(new Violation(e.Source, "WPN_EXPLOSION_BLACKLIST", ViolationSource.Server, With(evidence, "stealth", true)));

            if (e.DamageScale > _policy.MaxDamageScale)
                found.Add(new Violation(e.Source, "WPN_EXPLOSION_BLACKLIST", ViolationSource.Server, With(evidence, "reason", "damageScale")));

            string key = e.Source.ToString();
            int perSecond = _counter.Add(key + ":1", e.At, TimeSpan.FromSeconds(1));
            int perTen = _counter.Add(key + ":10", e.At, TimeSpan.FromSeconds(10));
            if (perSecond > _policy.MaxPerSecond || perTen > _policy.MaxPer10Seconds)
                found.Add(new Violation(e.Source, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server, With(evidence, "rate", perTen)));

            return (found, found.Count > 0);
        }

        public void Forget(int player) => _counter.RemoveWhere(k => k.StartsWith(player + ":", StringComparison.Ordinal));

        private static Dictionary<string, object?> With(Dictionary<string, object?> d, string k, object? v)
            => new Dictionary<string, object?>(d) { [k] = v };
    }

    public enum EntityKind { Unknown = 0, Ped = 1, Vehicle = 2, Object = 3 }

    public sealed class EntityPolicy
    {
        public HashSet<uint> BlacklistedModels { get; set; } = new HashSet<uint>();
        public HashSet<uint> AllowedPedModels { get; set; } = new HashSet<uint>();
        public List<string> AllowedPedModelNames { get; set; } = new List<string>();
        public int MaxVehiclesPer10s { get; set; } = 5;
        public int MaxEntitiesPer10s { get; set; } = 15;
        public int MaxAttachedToOthers { get; set; } = 2;
        public bool BlockUnknownScript { get; set; }
    }

    public readonly struct Attachment
    {
        public Attachment(int entity, int creator, int victim) { Entity = entity; Creator = creator; Victim = victim; }
        public int Entity { get; }
        public int Creator { get; }
        public int Victim { get; }
    }

    public static class EntityScriptCheck
    {
        public static Violation? Evaluate(int owner, bool scriptCreated, bool isPlayerPed, string? creatingResource, uint model, EntityKind kind)
        {
            if (owner <= 0 || !scriptCreated || isPlayerPed || !string.IsNullOrEmpty(creatingResource)) return null;
            return new Violation(owner, "ENT_UNKNOWN_SCRIPT", ViolationSource.Server, new Dictionary<string, object?>
            {
                ["model"] = model, ["kind"] = kind.ToString(), ["serverObserved"] = true,
            });
        }
    }

    public static class AttachmentWatch
    {
        public static (List<Violation> violations, List<int> remove) Evaluate(IEnumerable<Attachment> attachments, int maxPerCreator)
        {
            var violations = new List<Violation>();
            var remove = new List<int>();
            foreach (var group in attachments.Where(a => a.Creator > 0 && a.Victim > 0 && a.Creator != a.Victim).GroupBy(a => a.Creator))
            {
                var list = group.ToList();
                if (list.Count <= maxPerCreator) continue;
                violations.Add(new Violation(group.Key, "ENT_ATTACH_PLAYER", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["entities"] = list.Count, ["victims"] = list.Select(a => a.Victim).Distinct().Count(), ["serverObserved"] = true,
                }));
                remove.AddRange(list.Select(a => a.Entity));
            }
            return (violations, remove);
        }
    }

    public sealed class EntityValidator
    {
        private readonly EntityPolicy _policy;
        private readonly SlidingCounter _counter = new SlidingCounter();

        public EntityValidator(EntityPolicy policy) { _policy = policy; }

        public (List<Violation> violations, bool cancel) Evaluate(int owner, uint model, EntityKind kind, bool scriptCreated, DateTime now)
        {
            var found = new List<Violation>();
            if (owner <= 0) return (found, false);
            var evidence = new Dictionary<string, object?> { ["model"] = model, ["kind"] = kind.ToString(), ["script"] = scriptCreated };

            bool cancel = false;
            if (_policy.BlacklistedModels.Contains(model))
            {
                found.Add(new Violation(owner, kind == EntityKind.Vehicle ? "VEH_SPAWN" : "ENT_SPAWN_FLOOD", ViolationSource.Server, evidence));
                cancel = true;
            }

            if (scriptCreated)
            {
                string key = owner.ToString();
                int all = _counter.Add(key + ":all", now, TimeSpan.FromSeconds(10));
                if (all > _policy.MaxEntitiesPer10s)
                {
                    found.Add(new Violation(owner, "ENT_SPAWN_FLOOD", ViolationSource.Server, new Dictionary<string, object?>(evidence) { ["count"] = all }));
                    cancel = true;
                }
                if (kind == EntityKind.Vehicle)
                {
                    int veh = _counter.Add(key + ":veh", now, TimeSpan.FromSeconds(10));
                    if (veh > _policy.MaxVehiclesPer10s)
                    {
                        found.Add(new Violation(owner, "VEH_SPAWN", ViolationSource.Server, new Dictionary<string, object?>(evidence) { ["count"] = veh }));
                        cancel = true;
                    }
                }
            }
            return (found, cancel);
        }

        public Violation? CheckPedModel(int player, uint model)
        {
            if (_policy.AllowedPedModels.Count == 0 || _policy.AllowedPedModels.Contains(model)) return null;
            return new Violation(player, "PLY_PED_MODEL", ViolationSource.Server, new Dictionary<string, object?> { ["model"] = model });
        }

        public void Forget(int player) => _counter.RemoveWhere(k => k.StartsWith(player + ":", StringComparison.Ordinal));
    }

    public sealed class PlayerStateValidator
    {
        private readonly ConcurrentDictionary<int, (int health, int armor)> _last = new ConcurrentDictionary<int, (int, int)>();
        private readonly ConcurrentDictionary<string, DateTime> _grace = new ConcurrentDictionary<string, DateTime>(StringComparer.Ordinal);

        public int MaxHealth { get; set; } = 200;
        public int HealthJump { get; set; } = 25;
        public int ArmorJump { get; set; } = 10;

        public void GrantGrace(int player, string kind, TimeSpan duration, DateTime? now = null)
        {
            var until = (now ?? DateTime.UtcNow) + duration;
            _grace.AddOrUpdate(player + ":" + kind, until, (_, old) => old > until ? old : until);
        }

        public bool HasGrace(int player, string kind, DateTime? now = null)
            => _grace.TryGetValue(player + ":" + kind, out var until) && (now ?? DateTime.UtcNow) < until;

        public List<Violation> Evaluate(int player, int health, int armor, bool dead, DateTime now)
        {
            var found = new List<Violation>();
            if (dead) { _last.TryRemove(player, out _); return found; }

            if (health > MaxHealth + 1 && !HasGrace(player, "heal", now))
                found.Add(new Violation(player, "PLY_HEALTH_CAP", ViolationSource.Server, new Dictionary<string, object?> { ["health"] = health, ["max"] = MaxHealth }));

            if (_last.TryGetValue(player, out var prev))
            {
                if (health > prev.health + HealthJump && !HasGrace(player, "heal", now))
                    found.Add(new Violation(player, "PLY_HEALTH_REGEN", ViolationSource.Server, new Dictionary<string, object?> { ["from"] = prev.health, ["to"] = health }));
                if (armor > prev.armor + ArmorJump && !HasGrace(player, "armor", now))
                    found.Add(new Violation(player, "PLY_ARMOR_REGEN", ViolationSource.Server, new Dictionary<string, object?> { ["from"] = prev.armor, ["to"] = armor }));
            }
            _last[player] = (health, armor);
            return found;
        }

        public void Forget(int player)
        {
            _last.TryRemove(player, out _);
            foreach (var k in _grace.Keys)
                if (k.StartsWith(player + ":", StringComparison.Ordinal)) _grace.TryRemove(k, out _);
        }
    }
}
