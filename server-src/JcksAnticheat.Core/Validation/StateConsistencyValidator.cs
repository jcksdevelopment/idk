using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    public sealed class StateConsistencyValidator
    {
        private readonly ConcurrentDictionary<int, int> _streak = new ConcurrentDictionary<int, int>();

        public float PositionTolerance { get; set; } = 25f;
        public float SpeedToleranceSeconds { get; set; } = 2f;
        public int HealthTolerance { get; set; } = 40;
        public int ArmorTolerance { get; set; } = 40;
        public int StreakToReport { get; set; } = 3;

        public Violation? Evaluate(int player, int clientHealth, int clientArmor, Vec3 clientPos,
            int serverHealth, int serverArmor, Vec3 serverPos, float serverSpeed, bool skip)
        {
            if (skip)
            {
                _streak.TryRemove(player, out _);
                return null;
            }

            float posDelta = Vec3.Distance(clientPos, serverPos);
            int hpDelta = Math.Abs(clientHealth - serverHealth);
            int armorDelta = Math.Abs(clientArmor - serverArmor);
            bool mismatch = posDelta > PositionTolerance + serverSpeed * SpeedToleranceSeconds
                            || hpDelta > HealthTolerance
                            || armorDelta > ArmorTolerance;

            if (!mismatch)
            {
                _streak.TryRemove(player, out _);
                return null;
            }

            int streak = _streak.AddOrUpdate(player, 1, (_, s) => s + 1);
            if (streak < StreakToReport) return null;
            _streak.TryRemove(player, out _);
            return new Violation(player, "HB_STATE_MISMATCH", ViolationSource.Heartbeat, new Dictionary<string, object?>
            {
                ["clientHealth"] = clientHealth, ["serverHealth"] = serverHealth,
                ["clientArmor"] = clientArmor, ["serverArmor"] = serverArmor,
                ["posDelta"] = Math.Round(posDelta, 1), ["streak"] = streak,
            });
        }

        public void Forget(int player) => _streak.TryRemove(player, out _);
    }
}
