using System;
using System.Collections.Generic;
using System.Text;

namespace JcksAnticheat.Core.Validation
{
    public enum WeaponGroup { Melee, Pistol, Smg, Rifle, MachineGun, Shotgun, Sniper, Heavy, Thrown, Other }

    public sealed class WeaponSpec
    {
        public WeaponSpec(string name, WeaponGroup group, float baseDamage, float range, float roundsPerMinute, int pellets = 1)
        {
            Name = name; Group = group; BaseDamage = baseDamage; Range = range; RoundsPerMinute = roundsPerMinute; Pellets = pellets;
            Hash = Joaat.Hash(name);
        }
        public string Name { get; }
        public uint Hash { get; }
        public WeaponGroup Group { get; }
        public float BaseDamage { get; }
        public float Range { get; }
        public float RoundsPerMinute { get; }
        /// <summary>Shotguns produce one damage event per pellet hit.</summary>
        public int Pellets { get; }
    }

    /// <summary>
    /// Baseline weapon stats (approximate stock weapons.meta values). Used only as an upper bound,
    /// with generous multipliers, so modest inaccuracy here produces no false positives.
    /// Servers with weapon-balance mods should override entries in config.json.
    /// </summary>
    public static class WeaponCatalog
    {
        private static readonly Dictionary<uint, WeaponSpec> ByHash = new Dictionary<uint, WeaponSpec>();

        static WeaponCatalog()
        {
            void Add(string n, WeaponGroup g, float d, float r, float rpm, int pellets = 1) => Register(new WeaponSpec(n, g, d, r, rpm, pellets));

            Add("WEAPON_UNARMED", WeaponGroup.Melee, 15, 3, 120);
            Add("WEAPON_KNIFE", WeaponGroup.Melee, 45, 3, 120);
            Add("WEAPON_BAT", WeaponGroup.Melee, 25, 3.5f, 90);
            Add("WEAPON_NIGHTSTICK", WeaponGroup.Melee, 25, 3.5f, 90);
            Add("WEAPON_CROWBAR", WeaponGroup.Melee, 25, 3.5f, 90);

            Add("WEAPON_PISTOL", WeaponGroup.Pistol, 26, 120, 360);
            Add("WEAPON_PISTOL_MK2", WeaponGroup.Pistol, 32, 120, 360);
            Add("WEAPON_COMBATPISTOL", WeaponGroup.Pistol, 27, 120, 360);
            Add("WEAPON_APPISTOL", WeaponGroup.Pistol, 28, 120, 900);
            Add("WEAPON_PISTOL50", WeaponGroup.Pistol, 51, 120, 300);
            Add("WEAPON_HEAVYPISTOL", WeaponGroup.Pistol, 40, 120, 300);
            Add("WEAPON_SNSPISTOL", WeaponGroup.Pistol, 28, 120, 360);
            Add("WEAPON_VINTAGEPISTOL", WeaponGroup.Pistol, 34, 120, 360);
            Add("WEAPON_REVOLVER", WeaponGroup.Pistol, 110, 120, 60);
            Add("WEAPON_STUNGUN", WeaponGroup.Pistol, 1, 30, 60);

            Add("WEAPON_MICROSMG", WeaponGroup.Smg, 21, 120, 1000);
            Add("WEAPON_SMG", WeaponGroup.Smg, 22, 120, 750);
            Add("WEAPON_SMG_MK2", WeaponGroup.Smg, 25, 120, 800);
            Add("WEAPON_ASSAULTSMG", WeaponGroup.Smg, 23, 120, 750);
            Add("WEAPON_COMBATPDW", WeaponGroup.Smg, 28, 120, 750);
            Add("WEAPON_MACHINEPISTOL", WeaponGroup.Smg, 20, 120, 900);
            Add("WEAPON_MINISMG", WeaponGroup.Smg, 22, 120, 900);

            Add("WEAPON_ASSAULTRIFLE", WeaponGroup.Rifle, 30, 120, 600);
            Add("WEAPON_ASSAULTRIFLE_MK2", WeaponGroup.Rifle, 35, 120, 650);
            Add("WEAPON_CARBINERIFLE", WeaponGroup.Rifle, 32, 120, 650);
            Add("WEAPON_CARBINERIFLE_MK2", WeaponGroup.Rifle, 36, 120, 650);
            Add("WEAPON_ADVANCEDRIFLE", WeaponGroup.Rifle, 30, 120, 750);
            Add("WEAPON_SPECIALCARBINE", WeaponGroup.Rifle, 32, 120, 700);
            Add("WEAPON_BULLPUPRIFLE", WeaponGroup.Rifle, 32, 120, 700);
            Add("WEAPON_COMPACTRIFLE", WeaponGroup.Rifle, 34, 120, 650);

            Add("WEAPON_MG", WeaponGroup.MachineGun, 40, 120, 600);
            Add("WEAPON_COMBATMG", WeaponGroup.MachineGun, 45, 120, 750);
            Add("WEAPON_GUSENBERG", WeaponGroup.MachineGun, 34, 120, 800);

            Add("WEAPON_PUMPSHOTGUN", WeaponGroup.Shotgun, 29, 40, 70, 8);
            Add("WEAPON_SAWNOFFSHOTGUN", WeaponGroup.Shotgun, 40, 25, 70, 8);
            Add("WEAPON_ASSAULTSHOTGUN", WeaponGroup.Shotgun, 32, 40, 300, 6);
            Add("WEAPON_BULLPUPSHOTGUN", WeaponGroup.Shotgun, 14, 40, 200, 8);
            Add("WEAPON_HEAVYSHOTGUN", WeaponGroup.Shotgun, 117, 50, 200, 1);

            Add("WEAPON_SNIPERRIFLE", WeaponGroup.Sniper, 101, 1500, 50);
            Add("WEAPON_HEAVYSNIPER", WeaponGroup.Sniper, 216, 1500, 40);
            Add("WEAPON_HEAVYSNIPER_MK2", WeaponGroup.Sniper, 230, 1500, 40);
            Add("WEAPON_MARKSMANRIFLE", WeaponGroup.Sniper, 65, 1000, 150);
        }

        public static void Register(WeaponSpec spec) => ByHash[spec.Hash] = spec;

        public static WeaponSpec? Find(uint hash) => ByHash.TryGetValue(hash, out var s) ? s : null;

        public static IEnumerable<WeaponSpec> All => ByHash.Values;
    }

    /// <summary>GTA's Jenkins one-at-a-time hash (GetHashKey), lowercase-normalised.</summary>
    public static class Joaat
    {
        public static uint Hash(string input)
        {
            uint h = 0;
            foreach (var b in Encoding.UTF8.GetBytes(input.ToLowerInvariant()))
            {
                h += b;
                h += h << 10;
                h ^= h >> 6;
            }
            h += h << 3;
            h ^= h >> 11;
            h += h << 15;
            return h;
        }

        /// <summary>Natives return hashes as signed ints; normalise.</summary>
        public static uint FromSigned(long v) => unchecked((uint)v);
    }
}
