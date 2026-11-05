using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CitizenFX.Core;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Validation;
using JcksAnticheat.Core.Vision;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private int _tickCount;
        private readonly List<(int player, Violation violation, Vec3 to)> _tickTeleports = new List<(int, Violation, Vec3)>();
        private readonly List<(int player, Vec3 pos)> _tickPositions = new List<(int, Vec3)>();

        private async Task OnTick()
        {
            await Delay(1000);
            _tickCount++;

            var now = DateTime.UtcNow;
            DrainLicense(now);
            if (!_licensed) return;
            var players = Players.ToList();

            if (players.Count > 0)
            {
                _tickTeleports.Clear();
                _tickPositions.Clear();
                foreach (var p in players) CheckPlayerState(p, now);
                if (_tickTeleports.Count > 0)
                {
                    var outcome = MassTeleportDetector.Process(_tickTeleports, _tickPositions);
                    foreach (var v in outcome) Punish(v);
                    if (CountermeasureOn("MOV_BRING_ALL"))
                        foreach (var t in _tickTeleports)
                            if (!outcome.Contains(t.violation) && Players[t.player] is { } victim)
                                PutBack(t.player, GetPlayerPed(victim.Handle));
                }

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

            if (_tickCount % 60 == 0 && _vision.IsConfigured && !_cfg.DryRun && players.Count > 0)
            {
                foreach (var p in players)
                {
                    int pid = ToId(p.Handle);
                    double score = _ledger.ScoreOf(pid, now);
                    if (score >= _cfg.Scoring.ScreenshotAt && !_removing.ContainsKey(pid))
                        RequestScreenshot(pid, $"periodic: score {score:F0}");
                }
            }
            if (_tickCount % 10 == 0) _screenshots.Sweep(now);
            if (_tickCount % 600 == 0)
            {
                var dir = System.IO.Path.Combine(_dataDir, "vision");
                int keep = _cfg.Vision.MaxStoredCaptures;
                _ = Task.Run(() => CaptureRetention.Enforce(dir, keep));
            }
            DrainVisionResults();

            if (_tickCount % 3 == 0) _ = _discord.FlushAsync();
            if (_tickCount == 15 && _cfg.Backdoor.ScanOnStart) StartBackdoorScan("server start");
            if (!_scanResults.IsEmpty) DrainBackdoorResults();

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
            if (ped == 0) return;

            _heartbeats.ExpectHandshake(id, now);

            int health = GetEntityHealth(ped);
            int armor = GetPedArmour(ped);
            bool dead = health <= 100;

            int veh = GetVehiclePedIsIn(ped, false);
            var mode = dead ? MovementMode.Dead : veh == 0 ? MovementMode.OnFoot : ModeOf(GetVehicleType(veh));
            var subject = veh != 0 ? veh : ped;
            var sample = new MovementSample(ToVec(GetEntityCoords(subject)), ToVec(GetEntityVelocity(subject)), mode, now);

            _tickPositions.Add((id, sample.Position));
            foreach (var v in _movement.Evaluate(id, sample))
            {
                if (v.Code == "MOV_TELEPORT") _tickTeleports.Add((id, v, sample.Position));
                else Punish(v);
            }
            foreach (var v in _state.Evaluate(id, health, armor, dead, now)) Punish(v);

            if (!_state.HasGrace(id, "godmode", now) && GetPlayerInvincible(player.Handle))
                Punish(new Violation(id, "PLY_GODMODE_FLAG", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }));

            if (!_state.HasGrace(id, "invisible", now) && veh == 0 && !dead && !IsEntityVisible(ped))
                Punish(new Violation(id, "PLY_INVISIBLE", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }));

            if (veh != 0 && GetPedInVehicleSeat(veh, -1) == ped)
            {
                int netId = NetworkGetNetworkIdFromEntity(veh);
                int creator = _vehicles.CreatorOf(netId);
                var hijack = _vehicles.CheckDriver(id, netId, GetVehicleDoorLockStatus(veh),
                    creatorOnline: creator > 0 && Players[creator] != null, hasGrace: _state.HasGrace(id, "vehicle", now));
                if (hijack != null) Punish(hijack);
            }

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
