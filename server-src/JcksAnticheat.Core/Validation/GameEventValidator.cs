using System;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    public sealed class GameEventPolicy
    {
        /// <summary>Max distance between the shooter and where its projectile starts (on foot).</summary>
        public float ProjectileOriginMaxDistance { get; set; } = 12f;
        public int MaxProjectilesPer10s { get; set; } = 20;
        public int MaxFiresPer10s { get; set; } = 10;
        public int MaxPtfxPer10s { get; set; } = 40;
        public float MaxPtfxScale { get; set; } = 5f;
    }

    public sealed class ProjectileInfo
    {
        public int Source { get; set; }
        public uint WeaponHash { get; set; }
        public Vec3 Origin { get; set; }
        public Vec3 ShooterPos { get; set; }
        public bool ShooterInVehicle { get; set; }
        public bool OwnerIsShooter { get; set; } = true;
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    public sealed class FireInfo
    {
        public int Source { get; set; }
        /// <summary>Player whose ped a fire is attached to, or 0.</summary>
        public int TargetPlayer { get; set; }
        public int Count { get; set; } = 1;
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    public sealed class PtfxInfo
    {
        public int Source { get; set; }
        public float Scale { get; set; }
        /// <summary>Player whose entity the effect is attached to (other than the source), or 0.</summary>
        public int TargetPlayer { get; set; }
        public DateTime At { get; set; } = DateTime.UtcNow;
    }

    /// <summary>
    /// Validates the OneSync game events menus abuse for griefing: projectiles started out of thin
    /// air (rockets/bullets spawned at other players), fires set on other players, and particle
    /// spam (used to crash or blind players). Each check returns violations and whether to cancel.
    /// </summary>
    public sealed class GameEventValidator
    {
        private readonly GameEventPolicy _policy;
        private readonly Func<IReadOnlyCollection<uint>> _weaponBlacklist;
        private readonly SlidingCounter _counter = new SlidingCounter();

        public GameEventValidator(GameEventPolicy policy, Func<IReadOnlyCollection<uint>> weaponBlacklist)
        {
            _policy = policy;
            _weaponBlacklist = weaponBlacklist;
        }

        public (List<Violation> violations, bool cancel) Projectile(ProjectileInfo p)
        {
            var found = new List<Violation>();
            var ev = new Dictionary<string, object?> { ["weapon"] = p.WeaponHash };

            if (_weaponBlacklist().Contains(p.WeaponHash))
                found.Add(new Violation(p.Source, "WPN_BLACKLIST", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["via"] = "projectile" }));

            if (!p.OwnerIsShooter)
                found.Add(new Violation(p.Source, "WPN_PROJECTILE_ORIGIN", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["reason"] = "owner is another entity" }));
            else if (!p.ShooterInVehicle)
            {
                // Vehicle weapons fire from the vehicle's hardpoints, metres from the driver's ped.
                float d = Vec3.Distance(p.Origin, p.ShooterPos);
                if (d > _policy.ProjectileOriginMaxDistance)
                    found.Add(new Violation(p.Source, "WPN_PROJECTILE_ORIGIN", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["dist"] = Math.Round(d, 1) }));
            }

            int n = _counter.Add("proj:" + p.Source, p.At, TimeSpan.FromSeconds(10));
            if (n > _policy.MaxProjectilesPer10s)
                found.Add(new Violation(p.Source, "WPN_PROJECTILE_SPAM", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["per10s"] = n }));

            return (found, found.Count > 0);
        }

        public (List<Violation> violations, bool cancel) Fire(FireInfo f)
        {
            var found = new List<Violation>();
            if (f.TargetPlayer > 0 && f.TargetPlayer != f.Source)
                found.Add(new Violation(f.Source, "WPN_FIRE_PLAYER", ViolationSource.Server, new Dictionary<string, object?> { ["target"] = f.TargetPlayer }));
            int n = 0;
            for (int i = 0; i < Math.Max(1, f.Count); i++) n = _counter.Add("fire:" + f.Source, f.At, TimeSpan.FromSeconds(10));
            if (n > _policy.MaxFiresPer10s)
                found.Add(new Violation(f.Source, "WPN_FIRE_SPAM", ViolationSource.Server, new Dictionary<string, object?> { ["per10s"] = n }));
            return (found, found.Count > 0);
        }

        public (List<Violation> violations, bool cancel) Ptfx(PtfxInfo p)
        {
            var found = new List<Violation>();
            var ev = new Dictionary<string, object?> { ["scale"] = Math.Round(p.Scale, 2) };
            if (p.Scale > _policy.MaxPtfxScale)
                found.Add(new Violation(p.Source, "NET_PTFX_SPAM", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["reason"] = "scale" }));
            if (p.TargetPlayer > 0 && p.TargetPlayer != p.Source)
                found.Add(new Violation(p.Source, "NET_PTFX_SPAM", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["reason"] = "on another player", ["target"] = p.TargetPlayer }));
            int n = _counter.Add("ptfx:" + p.Source, p.At, TimeSpan.FromSeconds(10));
            if (n > _policy.MaxPtfxPer10s)
                found.Add(new Violation(p.Source, "NET_PTFX_SPAM", ViolationSource.Server, new Dictionary<string, object?>(ev) { ["per10s"] = n }));
            return (found, found.Count > 0);
        }

        public void Forget(int player) => _counter.RemoveWhere(k => k.EndsWith(":" + player, StringComparison.Ordinal));
    }
}
