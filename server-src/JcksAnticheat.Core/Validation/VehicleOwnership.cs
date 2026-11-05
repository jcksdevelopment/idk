using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    /// <summary>
    /// Remembers which player spawned each script-created vehicle, and flags another player sitting
    /// in its driver seat while it's locked: menus' "hijack / warp into vehicle" options. Lockpick
    /// and key scripts unlock the vehicle first, and job/garage scripts can grant "vehicle" grace.
    /// </summary>
    public sealed class VehicleOwnership
    {
        private readonly ConcurrentDictionary<int, int> _creator = new ConcurrentDictionary<int, int>();
        private readonly ConcurrentDictionary<string, bool> _reported = new ConcurrentDictionary<string, bool>(StringComparer.Ordinal);

        public void Track(int vehicleNetId, int creatorPlayer)
        {
            if (vehicleNetId != 0 && creatorPlayer > 0) _creator[vehicleNetId] = creatorPlayer;
        }

        public void Untrack(int vehicleNetId) => _creator.TryRemove(vehicleNetId, out _);

        public int CreatorOf(int vehicleNetId) => _creator.TryGetValue(vehicleNetId, out var p) ? p : 0;

        /// <summary>GTA door lock statuses that keep players out (locked, locked for player, locked-but-damageable, ...).</summary>
        public static bool IsLocked(int lockStatus) => lockStatus == 2 || lockStatus == 3 || lockStatus == 4 || lockStatus == 7 || lockStatus == 10;

        public Violation? CheckDriver(int driver, int vehicleNetId, int lockStatus, bool creatorOnline, bool hasGrace)
        {
            int creator = CreatorOf(vehicleNetId);
            if (creator == 0 || creator == driver || !creatorOnline || hasGrace || !IsLocked(lockStatus)) return null;
            if (!_reported.TryAdd(driver + ":" + vehicleNetId, true)) return null;
            return new Violation(driver, "VEH_HIJACK", ViolationSource.Server, new Dictionary<string, object?>
            {
                ["vehicle"] = vehicleNetId, ["owner"] = creator, ["lock"] = lockStatus,
            });
        }

        public void ForgetPlayer(int player)
        {
            foreach (var kv in _creator)
                if (kv.Value == player) _creator.TryRemove(kv.Key, out _);
            foreach (var k in _reported.Keys)
                if (k.StartsWith(player + ":", StringComparison.Ordinal)) _reported.TryRemove(k, out _);
        }
    }
}
