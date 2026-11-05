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
                    foreach (var v in outcome)
                    {
                        if (v.Code == "MOV_BRING_ALL") Punish(v);
                        else Defer(v.Player, "teleport", now, v, null);
                    }
                    if (CountermeasureOn("MOV_BRING_ALL"))
                        foreach (var t in _tickTeleports)
                            if (!outcome.Contains(t.violation))
                            {
                                int victimId = t.player;
                                Defer(victimId, "teleport", now, null, () =>
                                {
                                    if (Players[victimId] is { } victim) PutBack(victimId, GetPlayerPed(victim.Handle));
                                });
                            }
                }

                ResolveDeferred(now);

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
            if (_tickCount % 30 == 0) PushIntegrationSuggestions(false);
            if (_tickCount % 3 == 0 && players.Count > 1) CheckAttachments(players);
            if (_tickCount == 12 && _cfg.AuditOnStart) Log(RunAudit());
            if (_tickCount == 20) Log(RunDoctor());
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
            int carrier = veh == 0 ? GetEntityAttachedTo(ped) : 0;
            var mode = dead || carrier != 0 ? MovementMode.Dead : veh == 0 ? MovementMode.OnFoot : ModeOf(GetVehicleType(veh));
            var subject = veh != 0 ? veh : ped;
            var sample = new MovementSample(ToVec(GetEntityCoords(subject)), ToVec(GetEntityVelocity(subject)), mode, now);

            _tickPositions.Add((id, sample.Position));
            foreach (var v in _movement.Evaluate(id, sample))
            {
                if (v.Code == "MOV_TELEPORT") _tickTeleports.Add((id, v, sample.Position));
                else if (GraceKindFor(v.Code) is { } kind) Defer(id, kind, now, v, null);
                else Punish(v);
            }
            foreach (var v in _state.Evaluate(id, health, armor, dead, now))
            {
                if (GraceKindFor(v.Code) is { } kind) Defer(id, kind, now, v, null);
                else Punish(v);
            }

            var flags = new PlayerFlags(IsPlayerUsingSuperJump(player.Handle), GetPlayerWeaponDamageModifier(player.Handle),
                GetPlayerMeleeWeaponDamageModifier(player.Handle), GetPlayerWeaponDefenseModifier(player.Handle),
                GetPlayerWeaponDefenseModifier_2(player.Handle), GetPlayerMaxHealth(player.Handle),
                GetEntityCollisionDisabled(ped), GetEntityAttachedTo(ped) != 0, veh != 0, dead);
            ReleaseHeld(id, ped, veh, flags, player.Handle);
            foreach (var v in _flags.Evaluate(id, flags))
            {
                var kind = GraceKindFor(v.Code);
                if (kind != null && _state.HasGrace(id, kind, now)) continue;
                if (kind != null) Defer(id, kind, now, v, null);
                else Punish(v);
            }

            if (!_state.HasGrace(id, "godmode", now) && GetPlayerInvincible(player.Handle))
                Defer(id, "godmode", now, new Violation(id, "PLY_GODMODE_FLAG", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true }), null);

            if (!_state.HasGrace(id, "invisible", now) && !dead)
            {
                bool driving = veh != 0 && GetPedInVehicleSeat(veh, -1) == ped;
                if ((veh == 0 && !IsEntityVisible(ped)) || (driving && !IsEntityVisible(veh)))
                    Defer(id, "invisible", now, new Violation(id, "PLY_INVISIBLE", ViolationSource.Server, new Dictionary<string, object?> { ["serverObserved"] = true, ["vehicle"] = driving }), null);
            }

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

        private void ReleaseHeld(int id, int ped, int veh, PlayerFlags flags, string handle)
        {
            if (_state.IsHeld(id, "godmode") && !GetPlayerInvincible(handle) && flags.Defense >= _flags.MinDefense) _state.Release(id, "godmode");
            if (_state.IsHeld(id, "invisible") && IsEntityVisible(ped) && (veh == 0 || IsEntityVisible(veh))) _state.Release(id, "invisible");
            if (_state.IsHeld(id, "noclip") && !flags.CollisionDisabled) { _state.Release(id, "noclip"); _movement.RevokeGrace(id); }
            if (_state.IsHeld(id, "superjump") && !flags.SuperJump) _state.Release(id, "superjump");
            if (_state.IsHeld(id, "weapons") && flags.WeaponDamage <= _flags.ExpectedDamageModifier + _flags.Tolerance && flags.MeleeDamage <= _flags.ExpectedDamageModifier + _flags.Tolerance) _state.Release(id, "weapons");
        }

        private void CheckAttachments(List<Player> players)
        {
            var pedOwner = new Dictionary<int, int>();
            foreach (var p in players)
            {
                int ped = GetPlayerPed(p.Handle);
                if (ped != 0) pedOwner[ped] = ToId(p.Handle);
            }
            var found = new List<Attachment>();
            foreach (var list in new[] { GetAllObjects(), GetAllVehicles() })
            {
                if (!(list is IEnumerable<object> handles)) continue;
                foreach (var h in handles)
                {
                    int entity = Convert.ToInt32(h);
                    int to = GetEntityAttachedTo(entity);
                    if (to == 0 || !pedOwner.TryGetValue(to, out var victim)) continue;
                    found.Add(new Attachment(entity, NetworkGetFirstEntityOwner(entity), victim));
                }
            }
            if (found.Count == 0) return;
            var (violations, _) = AttachmentWatch.Evaluate(found, _cfg.Entities.MaxAttachedToOthers);
            foreach (var v in violations)
            {
                _attachRemoval = found.Where(a => a.Creator == v.Player && a.Victim != v.Player).Select(a => a.Entity).ToList();
                Punish(v);
                _attachRemoval = null;
            }
        }

        private List<int>? _attachRemoval;

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
