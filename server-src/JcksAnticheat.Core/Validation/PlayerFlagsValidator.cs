using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    public readonly struct PlayerFlags
    {
        public PlayerFlags(bool superJump, float weaponDamage, float meleeDamage, float defense, float defense2, int maxHealth,
            bool collisionDisabled, bool attached, bool inVehicle, bool dead)
        {
            SuperJump = superJump; WeaponDamage = weaponDamage; MeleeDamage = meleeDamage; Defense = defense; Defense2 = defense2;
            MaxHealth = maxHealth; CollisionDisabled = collisionDisabled; Attached = attached; InVehicle = inVehicle; Dead = dead;
        }
        public bool SuperJump { get; }
        public float WeaponDamage { get; }
        public float MeleeDamage { get; }
        public float Defense { get; }
        public float Defense2 { get; }
        public int MaxHealth { get; }
        public bool CollisionDisabled { get; }
        public bool Attached { get; }
        public bool InVehicle { get; }
        public bool Dead { get; }
    }

    public sealed class PlayerFlagsValidator
    {
        private readonly ConcurrentDictionary<int, int> _collisionStreak = new ConcurrentDictionary<int, int>();
        public double ExpectedDamageModifier { get; set; } = 1.0;
        public int MaxHealth { get; set; } = 200;
        public int CollisionStreak { get; set; } = 3;
        public float Tolerance { get; set; } = 0.05f;

        public void Forget(int player) => _collisionStreak.TryRemove(player, out _);

        public List<Violation> Evaluate(int player, PlayerFlags f)
        {
            var found = new List<Violation>();
            if (f.Dead) { _collisionStreak.TryRemove(player, out _); return found; }

            if (f.SuperJump)
                found.Add(Server(player, "PLY_SUPERJUMP", new Dictionary<string, object?> { ["superJumpFlag"] = true }));

            if (Math.Abs(f.WeaponDamage - ExpectedDamageModifier) > Tolerance || Math.Abs(f.MeleeDamage - ExpectedDamageModifier) > Tolerance)
                found.Add(Server(player, "WPN_DMG_MODIFIER", new Dictionary<string, object?>
                {
                    ["weapon"] = Math.Round(f.WeaponDamage, 2), ["melee"] = Math.Round(f.MeleeDamage, 2),
                }));

            if (f.Defense < 1f - Tolerance || f.Defense2 < 1f - Tolerance)
                found.Add(Server(player, "PLY_GODMODE_PROOFS", new Dictionary<string, object?>
                {
                    ["defense"] = Math.Round(f.Defense, 2), ["defense2"] = Math.Round(f.Defense2, 2),
                }));

            if (f.MaxHealth > MaxHealth)
                found.Add(Server(player, "PLY_HEALTH_CAP", new Dictionary<string, object?> { ["maxHealth"] = f.MaxHealth, ["cap"] = MaxHealth }));

            if (f.CollisionDisabled && !f.Attached && !f.InVehicle)
            {
                int streak = _collisionStreak.AddOrUpdate(player, 1, (_, n) => n + 1);
                if (streak >= CollisionStreak)
                {
                    found.Add(Server(player, "MOV_NOCLIP_COLLISION", new Dictionary<string, object?> { ["seconds"] = streak }));
                    _collisionStreak[player] = 0;
                }
            }
            else _collisionStreak.TryRemove(player, out _);

            return found;
        }

        private static Violation Server(int player, string code, Dictionary<string, object?> evidence)
        {
            evidence["serverObserved"] = true;
            return new Violation(player, code, ViolationSource.Server, evidence);
        }
    }
}
