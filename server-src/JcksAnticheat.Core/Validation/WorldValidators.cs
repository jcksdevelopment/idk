using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
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
        /// <summary>Player who owns the explosion's owner entity (ownerNetId), or 0 if none/not a player.</summary>
        public int OwnerPlayer { get; set; }
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    public sealed class ExplosionPolicy
    {
        /// <summary>eExplosionTag values a player-originated event may never use.</summary>
        public HashSet<int> Blacklist { get; set; } = new HashSet<int>
        {
            16, // SHIP_DESTROY
            18, // BULLET: explosive ammo
            26, // TRAIN
            29, // BLIMP
            32, // PLANE_ROCKET
            35, // BIRD_CRAP
            36, // RAILGUN
            37, // BLIMP2
            41, // VALKYRIE_CANNON
        };
        public int MaxPerSecond { get; set; } = 4;
        public int MaxPer10Seconds { get; set; } = 12;
        public float MaxDamageScale { get; set; } = 1.5f;
    }

    public sealed class ExplosionValidator
    {
        /// <summary>
        /// eExplosionTag values created directly by a player's weapon: grenade, grenade launcher,
        /// sticky bomb, molotov, rocket, tank shell, explosive ammo, plane rocket, vehicle bullet,
        /// railgun, proximity mine.
        /// </summary>
        public static readonly HashSet<int> WeaponExplosionTypes = new HashSet<int> { 0, 1, 2, 3, 4, 5, 18, 32, 33, 36, 40 };

        private readonly ExplosionPolicy _policy;
        private readonly SlidingCounter _counter = new SlidingCounter();

        public ExplosionValidator(ExplosionPolicy policy) { _policy = policy; }

        /// <summary>Returns violations and whether the event should be cancelled.</summary>
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

            // Owned explosions blamed on someone else: the owner entity belongs to a different player.
            // Only for weapon explosions, which the shooter's own client creates. When a vehicle or
            // object is destroyed, the client that owns it sends the explosion with the attacker as
            // owner, which legitimately differs from the sender.
            if (e.OwnerPlayer > 0 && e.OwnerPlayer != e.Source && WeaponExplosionTypes.Contains(e.ExplosionType))
                found.Add(new Violation(e.Source, "WPN_EXPLOSION_BLAME", ViolationSource.Server, With(evidence, "owner", e.OwnerPlayer)));

            // Stealth explosions (invisible + silent) are a menu signature; the game doesn't make these itself.
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
        /// <summary>Names behind AllowedPedModels, kept so the config can be written back.</summary>
        public List<string> AllowedPedModelNames { get; set; } = new List<string>();
        public int MaxVehiclesPer10s { get; set; } = 5;
        public int MaxEntitiesPer10s { get; set; } = 15;
    }

    public sealed class EntityValidator
    {
        private readonly EntityPolicy _policy;
        private readonly SlidingCounter _counter = new SlidingCounter();

        public EntityValidator(EntityPolicy policy) { _policy = policy; }

        /// <summary>Evaluates an entityCreating event. Returns violations and whether to cancel creation.</summary>
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

            // Only script-created entities count toward floods. Ambient population is created by clients too.
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

        /// <summary>Server-side ped model check, used from the state tick.</summary>
        public Violation? CheckPedModel(int player, uint model)
        {
            if (_policy.AllowedPedModels.Count == 0 || _policy.AllowedPedModels.Contains(model)) return null;
            return new Violation(player, "PLY_PED_MODEL", ViolationSource.Server, new Dictionary<string, object?> { ["model"] = model });
        }

        public void Forget(int player) => _counter.RemoveWhere(k => k.StartsWith(player + ":", StringComparison.Ordinal));
    }

    /// <summary>
    /// Server-observed health and armour. A jump with no server-authorised heal is a health lock or
    /// regen cheat. Only server grace counts here: client-side grace can be forged.
    /// </summary>
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
