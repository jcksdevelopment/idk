using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Core.Validation
{
    public enum MovementMode { OnFoot, LandVehicle, Boat, Aircraft, Dead }

    public readonly struct MovementSample
    {
        public MovementSample(Vec3 position, Vec3 velocity, MovementMode mode, DateTime at, float heightAboveGround = 0)
        {
            Position = position; Velocity = velocity; Mode = mode; At = at; HeightAboveGround = heightAboveGround;
        }
        public Vec3 Position { get; }
        public Vec3 Velocity { get; }
        public MovementMode Mode { get; }
        public DateTime At { get; }
        public float HeightAboveGround { get; }
    }

    public sealed class MovementLimits
    {
        public float OnFootMaxSpeed { get; set; } = 12f;
        public float LandMaxSpeed { get; set; } = 110f;
        public float BoatMaxSpeed { get; set; } = 60f;
        public float AirMaxSpeed { get; set; } = 160f;
        public float FallSpeed { get; set; } = 70f;
        public float TeleportMinDistance { get; set; } = 60f;
        public float SpeedSlack { get; set; } = 1.35f;
        public float OnFootMaxRise { get; set; } = 15f;
    }

    public sealed class MovementValidator
    {
        private readonly ConcurrentDictionary<int, MovementSample> _last = new ConcurrentDictionary<int, MovementSample>();
        private readonly ConcurrentDictionary<int, DateTime> _grace = new ConcurrentDictionary<int, DateTime>();
        private readonly ConcurrentDictionary<int, Vec3> _lastGood = new ConcurrentDictionary<int, Vec3>();

        public Vec3? LastGood(int player) => _lastGood.TryGetValue(player, out var p) ? p : (Vec3?)null;
        private readonly MovementLimits _limits;

        public MovementValidator(MovementLimits limits) { _limits = limits; }

        public void GrantGrace(int player, TimeSpan duration, DateTime? now = null)
        {
            var until = (now ?? DateTime.UtcNow) + duration;
            _grace.AddOrUpdate(player, until, (_, old) => old > until ? old : until);
        }

        public void RevokeGrace(int player) => _grace.TryRemove(player, out _);

        public void Forget(int player)
        {
            _last.TryRemove(player, out _);
            _grace.TryRemove(player, out _);
            _lastGood.TryRemove(player, out _);
        }

        public float MaxSpeed(MovementMode mode)
        {
            switch (mode)
            {
                case MovementMode.OnFoot: return _limits.OnFootMaxSpeed;
                case MovementMode.LandVehicle: return _limits.LandMaxSpeed;
                case MovementMode.Boat: return _limits.BoatMaxSpeed;
                case MovementMode.Aircraft: return _limits.AirMaxSpeed;
                default: return float.MaxValue;
            }
        }

        public List<Violation> Evaluate(int player, MovementSample sample)
        {
            var found = new List<Violation>();
            bool inGrace = _grace.TryGetValue(player, out var until) && sample.At < until;

            if (_last.TryGetValue(player, out var prev) && !inGrace
                && prev.Mode != MovementMode.Dead && sample.Mode != MovementMode.Dead)
            {
                double dt = (sample.At - prev.At).TotalSeconds;
                if (dt > 0.2 && dt < 10)
                {
                    var delta = sample.Position - prev.Position;
                    float horizontal = delta.Length2D;
                    float up = Math.Max(0, delta.Z);
                    float distance = (float)Math.Sqrt(horizontal * horizontal + up * up);
                    float speed = (float)(distance / dt);
                    float allowed = Math.Max(MaxSpeed(prev.Mode), MaxSpeed(sample.Mode)) * _limits.SpeedSlack;

                    if (speed > allowed && distance >= _limits.TeleportMinDistance)
                    {
                        found.Add(new Violation(player, "MOV_TELEPORT", ViolationSource.Server, new Dictionary<string, object?>
                        {
                            ["from"] = prev.Position.ToString(), ["to"] = sample.Position.ToString(),
                            ["dist"] = Math.Round(distance, 1), ["dt"] = Math.Round(dt, 2), ["mode"] = sample.Mode.ToString(),
                        }));
                    }
                    else if (speed > allowed && prev.Mode == sample.Mode)
                    {
                        string code = sample.Mode == MovementMode.OnFoot ? "PLY_SPEED_FOOT" : "MOV_SPEED_VEH";
                        found.Add(new Violation(player, code, ViolationSource.Server, new Dictionary<string, object?>
                        {
                            ["speed"] = Math.Round(speed, 1), ["max"] = Math.Round(allowed, 1), ["mode"] = sample.Mode.ToString(),
                        }));
                    }

                    if (sample.Mode == MovementMode.OnFoot && prev.Mode == MovementMode.OnFoot)
                    {
                        float rise = (float)(delta.Z / dt);
                        if (rise > _limits.OnFootMaxRise)
                        {
                            found.Add(new Violation(player, "MOV_NOCLIP_ZVEL", ViolationSource.Server, new Dictionary<string, object?>
                            {
                                ["rise"] = Math.Round(rise, 1),
                            }));
                        }
                    }
                }
            }

            if (_last.TryGetValue(player, out var before) && before.Position.Equals(sample.Position) && before.Mode == sample.Mode && sample.At - before.At < TimeSpan.FromSeconds(3))
                sample = new MovementSample(sample.Position, sample.Velocity, sample.Mode, before.At, sample.HeightAboveGround);
            _last[player] = sample;
            if (found.Count == 0 && sample.Mode != MovementMode.Dead) _lastGood[player] = sample.Position;
            return found;
        }
    }
}
