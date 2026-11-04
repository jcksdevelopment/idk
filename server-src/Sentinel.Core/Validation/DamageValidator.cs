using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using Sentinel.Core.Detection;

namespace Sentinel.Core.Validation
{
    /// <summary>A weaponDamageEvent joined with server-side positions of both peds.</summary>
    public sealed class WeaponHit
    {
        public int Attacker { get; set; }
        /// <summary>Victim player id, or 0 when the victim is not a player.</summary>
        public int VictimPlayer { get; set; }
        public int VictimNetId { get; set; }
        public uint WeaponHash { get; set; }
        public float Damage { get; set; }
        public bool Headshot { get; set; }
        public bool WillKill { get; set; }
        public Vec3 AttackerPos { get; set; }
        public float AttackerHeading { get; set; }
        public bool AttackerInVehicle { get; set; }
        public Vec3 VictimPos { get; set; }
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    public sealed class DamageLimits
    {
        public float BodyDamageMultiplier { get; set; } = 1.6f;
        public float HeadDamageMultiplier { get; set; } = 4.0f;
        public float RangeMultiplier { get; set; } = 1.25f;
        /// <summary>Above this angle between the shooter's facing and the victim, a hit is implausible.</summary>
        public float MaxAimAngle { get; set; } = 60f;
        /// <summary>The angle check is skipped closer than this (point-blank, melee, body overlap).</summary>
        public float AimAngleMinDistance { get; set; } = 4f;
        public float RateMultiplier { get; set; } = 1.5f;
        public int HeadshotSampleSize { get; set; } = 25;
        public double HeadshotRatioMax { get; set; } = 0.7;
        public float HeadshotMinDistance { get; set; } = 15f;
    }

    /// <summary>
    /// Validates each weaponDamageEvent against weapon baselines and geometry the attacker can't spoof:
    /// damage scaling, range, silent-aim angle, rate of fire, and long-run headshot ratio.
    /// </summary>
    public sealed class DamageValidator
    {
        private sealed class ShooterStats
        {
            public int RangedHits;
            public int Headshots;
            public readonly Queue<DateTime> RecentHits = new Queue<DateTime>();
            public uint RecentWeapon;
        }

        private readonly ConcurrentDictionary<int, ShooterStats> _stats = new ConcurrentDictionary<int, ShooterStats>();
        private readonly DamageLimits _limits;

        public DamageValidator(DamageLimits limits) { _limits = limits; }

        public void Forget(int player) => _stats.TryRemove(player, out _);

        public List<Violation> Evaluate(WeaponHit hit)
        {
            var found = new List<Violation>();
            var spec = WeaponCatalog.Find(hit.WeaponHash);
            float distance = Vec3.Distance(hit.AttackerPos, hit.VictimPos);
            Dictionary<string, object?> Evidence(params (string k, object? v)[] extra)
            {
                var d = new Dictionary<string, object?>
                {
                    ["weapon"] = spec?.Name ?? hit.WeaponHash.ToString(), ["dist"] = Math.Round(distance, 1),
                    ["dmg"] = hit.Damage, ["victim"] = hit.VictimPlayer,
                };
                foreach (var (k, v) in extra) d[k] = v;
                return d;
            }

            if (spec != null)
            {
                // Damage scaling.
                if (hit.Damage > 0 && spec.Group != WeaponGroup.Melee)
                {
                    float mult = hit.Headshot ? _limits.HeadDamageMultiplier : _limits.BodyDamageMultiplier;
                    float cap = spec.BaseDamage * mult;
                    if (hit.Damage > cap)
                        found.Add(new Violation(hit.Attacker, "WPN_DMG_MODIFIER", ViolationSource.Server, Evidence(("cap", Math.Round(cap, 1)))));
                }

                // Range.
                float maxRange = spec.Range * _limits.RangeMultiplier;
                if (distance > maxRange)
                    found.Add(new Violation(hit.Attacker, "WPN_RANGE", ViolationSource.Server, Evidence(("max", Math.Round(maxRange, 1)))));
            }

            // Silent aim: the shooter is facing well away from the victim at the moment of the hit.
            // Drive-bys and vehicle weapons aim independently of ped heading, so they're skipped.
            if (!hit.AttackerInVehicle && distance > _limits.AimAngleMinDistance && spec?.Group != WeaponGroup.Melee)
            {
                var facing = Vec3.FromHeading(hit.AttackerHeading);
                var toVictim = hit.VictimPos - hit.AttackerPos;
                float angle = Vec3.Angle2D(facing, toVictim);
                if (angle > _limits.MaxAimAngle)
                    found.Add(new Violation(hit.Attacker, "WPN_AIM_ANGLE", ViolationSource.Server, Evidence(("angle", Math.Round(angle, 1)))));
            }

            var stats = _stats.GetOrAdd(hit.Attacker, _ => new ShooterStats());
            lock (stats)
            {
                // Rate of fire, per weapon, over a 1-second window.
                if (spec != null && spec.Group != WeaponGroup.Melee)
                {
                    if (stats.RecentWeapon != hit.WeaponHash) { stats.RecentHits.Clear(); stats.RecentWeapon = hit.WeaponHash; }
                    stats.RecentHits.Enqueue(hit.At);
                    var cutoff = hit.At.AddSeconds(-1);
                    while (stats.RecentHits.Count > 0 && stats.RecentHits.Peek() < cutoff) stats.RecentHits.Dequeue();
                    double maxPerSecond = spec.RoundsPerMinute / 60.0 * spec.Pellets * _limits.RateMultiplier + 1;
                    if (stats.RecentHits.Count > maxPerSecond)
                    {
                        found.Add(new Violation(hit.Attacker, "WPN_RAPID_FIRE", ViolationSource.Server,
                            Evidence(("perSec", stats.RecentHits.Count), ("max", Math.Round(maxPerSecond, 1)))));
                        stats.RecentHits.Clear();
                    }
                }

                // Headshot ratio on ranged hits against players.
                if (hit.VictimPlayer != 0 && distance >= _limits.HeadshotMinDistance && spec?.Group != WeaponGroup.Melee && spec?.Group != WeaponGroup.Shotgun)
                {
                    stats.RangedHits++;
                    if (hit.Headshot) stats.Headshots++;
                    if (stats.RangedHits >= _limits.HeadshotSampleSize)
                    {
                        double ratio = (double)stats.Headshots / stats.RangedHits;
                        if (ratio > _limits.HeadshotRatioMax)
                            found.Add(new Violation(hit.Attacker, "WPN_HEADSHOT_RATIO", ViolationSource.Server,
                                Evidence(("ratio", Math.Round(ratio, 2)), ("n", stats.RangedHits))));
                        stats.RangedHits = 0;
                        stats.Headshots = 0;
                    }
                }
            }

            return found;
        }
    }

    /// <summary>
    /// Semi-godmode detection: the server confirms hits on a player but their health never drops.
    /// Hits are queued and checked about a second later, once the victim's health has replicated.
    /// </summary>
    public sealed class AbsorbTracker
    {
        private readonly struct Pending
        {
            public Pending(int victim, int healthBefore, int armorBefore, DateTime due) { Victim = victim; HealthBefore = healthBefore; ArmorBefore = armorBefore; Due = due; }
            public int Victim { get; }
            public int HealthBefore { get; }
            public int ArmorBefore { get; }
            public DateTime Due { get; }
        }

        private readonly ConcurrentQueue<Pending> _pending = new ConcurrentQueue<Pending>();
        private readonly SlidingCounter _absorbed = new SlidingCounter();

        public int Threshold { get; set; } = 6;
        public TimeSpan Window { get; set; } = TimeSpan.FromSeconds(30);

        public void RecordHit(int victim, int healthBefore, int armorBefore, DateTime now)
            => _pending.Enqueue(new Pending(victim, healthBefore, armorBefore, now.AddSeconds(1.2)));

        public bool HasPending => !_pending.IsEmpty;

        /// <summary>Process hits whose check time has passed. healthOf returns (health, armor, isDead, isOnline).</summary>
        public List<Violation> Process(DateTime now, Func<int, (int health, int armor, bool dead, bool online)> healthOf, Func<int, bool> hasGodmodeGrace)
        {
            var found = new List<Violation>();
            while (_pending.TryPeek(out var p) && p.Due <= now)
            {
                _pending.TryDequeue(out _);
                var (health, armor, dead, online) = healthOf(p.Victim);
                if (!online || dead || hasGodmodeGrace(p.Victim)) continue;
                if (health >= p.HealthBefore && armor >= p.ArmorBefore)
                {
                    int count = _absorbed.Add(p.Victim.ToString(), now, Window);
                    if (count >= Threshold)
                    {
                        found.Add(new Violation(p.Victim, "PLY_DAMAGE_ABSORB", ViolationSource.Server, new Dictionary<string, object?>
                        {
                            ["absorbed"] = count, ["health"] = health, ["armor"] = armor,
                        }));
                        _absorbed.RemoveWhere(k => k == p.Victim.ToString());
                    }
                }
            }
            return found;
        }
    }
}
