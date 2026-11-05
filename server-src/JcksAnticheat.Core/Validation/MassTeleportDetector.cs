using System;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    /// <summary>
    /// "Bring all players": a menu teleports many players onto itself at once. Each victim would
    /// otherwise get MOV_TELEPORT. When several teleports in one tick land in the same spot, the
    /// victims' violations are dropped and the player standing at that spot who did NOT teleport
    /// (the one everybody was pulled to) is reported instead.
    /// </summary>
    public static class MassTeleportDetector
    {
        public const int MinVictims = 3;
        public const float ClusterRadius = 25f;
        public const float CulpritRadius = 30f;

        public static List<Violation> Process(List<(int player, Violation violation, Vec3 to)> teleports, IList<(int player, Vec3 pos)> everyone)
        {
            var result = new List<Violation>();
            var remaining = new List<(int player, Violation violation, Vec3 to)>(teleports);

            while (remaining.Count > 0)
            {
                var seed = remaining[0];
                var cluster = remaining.Where(t => Vec3.Distance(t.to, seed.to) <= ClusterRadius).ToList();
                if (cluster.Count < MinVictims)
                {
                    result.Add(seed.violation);
                    remaining.RemoveAt(0);
                    continue;
                }
                foreach (var c in cluster) remaining.Remove(c);

                var center = new Vec3(cluster.Average(c => c.to.X), cluster.Average(c => c.to.Y), cluster.Average(c => c.to.Z));
                var victims = new HashSet<int>(cluster.Select(c => c.player));
                var culprit = everyone.Where(p => !victims.Contains(p.player))
                    .Select(p => (p.player, dist: Vec3.Distance(p.pos, center)))
                    .Where(p => p.dist <= CulpritRadius)
                    .OrderBy(p => p.dist)
                    .FirstOrDefault();
                if (culprit.player > 0)
                {
                    result.Add(new Violation(culprit.player, "MOV_BRING_ALL", ViolationSource.Server, new Dictionary<string, object?>
                    {
                        ["victims"] = victims.Count, ["at"] = center.ToString(), ["dist"] = Math.Round(culprit.dist, 1),
                    }));
                }
            }
            return result;
        }
    }
}
