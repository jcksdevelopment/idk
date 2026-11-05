using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CitizenFX.Core;
using Sentinel.Core.Detection;
using Sentinel.Core.Validation;
using Sentinel.Core.Vision;
using static CitizenFX.Core.Native.API;

namespace Sentinel.Server
{
    public sealed partial class SentinelScript
    {
        private int _tickCount;

        /// <summary>
        /// Runs once per second. With no players online it touches nothing and goes straight back to
        /// sleep, which is what keeps idle resmon at 0.00 ms.
        /// </summary>
        private async Task OnTick()
        {
            await Delay(1000);
            _tickCount++;

            var players = Players.ToList();
            var now = DateTime.UtcNow;

            if (players.Count > 0)
            {
                foreach (var p in players) CheckPlayerState(p, now);

                foreach (var (player, silent) in _heartbeats.FindMissing(now))
                    Punish(new Violation(player, "HB_MISSING", ViolationSource.Heartbeat, new Dictionary<string, object?>
                    {
                        ["silentSec"] = (int)silent.TotalSeconds,
                        ["handshake"] = _heartbeats.HasSession(player),
                    }));

                if (_absorb.HasPending)
                {
                    foreach (var v in _absorb.Process(now, HealthOf, id => _state.HasGrace(id, "godmode", now)))
                        Punish(v);
                }
            }

            if (!_removing.IsEmpty) ProcessScheduledDrops(now);
            if (_tickCount % 10 == 0) _screenshots.Sweep(now);
            DrainVisionResults();

            if (_dashboard.Enabled)
            {
                if (_tickCount % Math.Max(1, _cfg.Dashboard.FlushSeconds) == 0)
                {
                    if (_tickCount % 5 == 0 && players.Count > 0)
                        _dashboard.Enqueue("players", players.Select(PlayerSnapshot).ToList());
                    _ = _dashboard.FlushAsync();
                }
                if (_tickCount % Math.Max(1, _cfg.Dashboard.PollSeconds) == 0) _ = _dashboard.PollAsync();
                while (_dashboard.TryDequeueCommand(out var cmd) && cmd != null) ExecuteCommand(cmd);
            }
        }

        private void CheckPlayerState(Player player, DateTime now)
        {
            int id = ToId(player.Handle);
            int ped = GetPlayerPed(player.Handle);
            // Server-side checks don't wait for the handshake: a client that blocks sentinel:hello
            // must not switch off the server's own movement and health validation.
            if (ped == 0) return; // no ped yet: still downloading or loading in

            // The handshake clock starts once the player is in the world, not at join: first-time
            // players can spend minutes downloading resources before any client script runs.
            _heartbeats.ExpectHandshake(id, now);

            int health = GetEntityHealth(ped);
            int armor = GetPedArmour(ped);
            bool dead = health <= 100; // MP peds die at or below 100 of 200

            int veh = GetVehiclePedIsIn(ped, false);
            var mode = dead ? MovementMode.Dead : veh == 0 ? MovementMode.OnFoot : ModeOf(GetVehicleType(veh));
            var subject = veh != 0 ? veh : ped;
            var sample = new MovementSample(ToVec(GetEntityCoords(subject)), ToVec(GetEntityVelocity(subject)), mode, now);

            foreach (var v in _movement.Evaluate(id, sample)) Punish(v);
            foreach (var v in _state.Evaluate(id, health, armor, dead, now)) Punish(v);

            if (!_state.HasGrace(id, "godmode", now) && GetPlayerInvincible(player.Handle))
                Punish(new Violation(id, "PLY_GODMODE_FLAG", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }));

            if (!_state.HasGrace(id, "invisible", now) && veh == 0 && !dead && !IsEntityVisible(ped))
                Punish(new Violation(id, "PLY_INVISIBLE", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }));

            uint weapon = Joaat.FromSigned(GetSelectedPedWeapon(ped));
            if (_weaponBlacklist.Contains(weapon))
            {
                RemoveWeaponFromPed(ped, weapon);
                Punish(new Violation(id, "WPN_BLACKLIST", ViolationSource.Server, new Dictionary<string, object?> { ["weapon"] = weapon, ["serverObserved"] = true }));
            }

            var pedModel = _entities.CheckPedModel(id, Joaat.FromSigned(GetEntityModel(ped)));
            if (pedModel != null) Punish(pedModel);
        }

        private static MovementMode ModeOf(string vehicleType)
        {
            switch (vehicleType)
            {
                case "heli":
                case "plane":
                case "blimp":
                    return MovementMode.Aircraft;
                case "boat":
                case "submarine":
                    return MovementMode.Boat;
                default:
                    return MovementMode.LandVehicle;
            }
        }

        private (int health, int armor, bool dead, bool online) HealthOf(int player)
        {
            var p = Players[player];
            if (p == null) return (0, 0, false, false);
            int ped = GetPlayerPed(p.Handle);
            int health = GetEntityHealth(ped);
            return (health, GetPedArmour(ped), health <= 100, true);
        }

        private void DrainVisionResults()
        {
            while (_visionResults.TryDequeue(out var item))
            {
                var (shot, verdict) = item;
                var name = Players[shot.Player]?.Name ?? ("#" + shot.Player);
                Log($"vision {shot.Id} {name}: {verdict.Verdict} ({verdict.Confidence:F2}) {verdict.Summary}{(verdict.Error != null ? " error=" + verdict.Error : "")}");

                _dashboard.Enqueue("vision", new Dictionary<string, object?>
                {
                    ["id"] = shot.Id, ["player"] = shot.Player, ["name"] = name, ["reason"] = shot.Reason,
                    ["image"] = Convert.ToBase64String(shot.Jpeg), ["verdict"] = verdict,
                });

                if (verdict.Verdict == VisionVerdictKind.Cheat && verdict.Confidence >= _cfg.Vision.FlagConfidence)
                {
                    Punish(new Violation(shot.Player, "VIS_AI_FLAG", ViolationSource.Vision, new Dictionary<string, object?>
                    {
                        ["capture"] = shot.Id, ["confidence"] = verdict.Confidence, ["summary"] = verdict.Summary,
                    }));
                }
            }
        }
    }
}
