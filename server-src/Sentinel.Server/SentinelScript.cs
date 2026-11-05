using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using CitizenFX.Core;
using Sentinel.Core.Bans;
using Sentinel.Core.Config;
using Sentinel.Core.Dashboard;
using Sentinel.Core.Detection;
using Sentinel.Core.Heartbeat;
using Sentinel.Core.Json;
using Sentinel.Core.Validation;
using Sentinel.Core.Vision;
using static CitizenFX.Core.Native.API;

namespace Sentinel.Server
{
    /// <summary>
    /// Server authority. Wires FiveM events into the pure validators in Sentinel.Core and enforces
    /// the verdicts. Idle cost: one coroutine that wakes once per second and returns at once when
    /// nobody is online; every other path is event-driven.
    /// </summary>
    public sealed partial class SentinelScript : BaseScript
    {
        private readonly string _resource;
        private readonly SentinelConfig _cfg;
        private readonly ViolationLedger _ledger;
        private readonly RateLimiter _limiter = new RateLimiter();
        private readonly RateLimiter.Rule _eventRule;
        private readonly RateLimiter.Rule _helloRule = new RateLimiter.Rule(3, 0.05);
        private readonly SlidingCounter _denied = new SlidingCounter();
        private readonly HeartbeatManager _heartbeats = new HeartbeatManager();
        private readonly MovementValidator _movement;
        private readonly DamageValidator _damage;
        private readonly AbsorbTracker _absorb = new AbsorbTracker();
        private readonly ExplosionValidator _explosions;
        private readonly EntityValidator _entities;
        private readonly PlayerStateValidator _state;
        private readonly BanStore _bans;
        private readonly ScreenshotAssembler _screenshots = new ScreenshotAssembler();
        private readonly AIVisionEvaluator _vision;
        private readonly DashboardBridge _dashboard;
        private readonly HashSet<uint> _weaponBlacklist;
        private readonly string _dataDir;

        // Per-boot random event names. Only "sentinel:hello" and "sentinel:init" are fixed.
        private readonly string _hbEvent = HeartbeatManager.RandomEventName();
        private readonly string _ackEvent = HeartbeatManager.RandomEventName();
        private readonly string _graceEvent = HeartbeatManager.RandomEventName();
        private readonly string _ssRequestEvent = HeartbeatManager.RandomEventName();
        private readonly string _ssUploadEvent = HeartbeatManager.RandomEventName();

        private readonly ConcurrentQueue<(ScreenshotAssembler.Completed shot, VisionVerdict verdict)> _visionResults =
            new ConcurrentQueue<(ScreenshotAssembler.Completed, VisionVerdict)>();
        private readonly ConcurrentDictionary<int, DateTime> _lastCapture = new ConcurrentDictionary<int, DateTime>();

        public SentinelScript()
        {
            _resource = GetCurrentResourceName();
            var raw = LoadResourceFile(_resource, "config.json");
            _cfg = SentinelConfig.Parse(string.IsNullOrWhiteSpace(raw) ? "{}" : raw);

            _ledger = new ViolationLedger(_cfg.Scoring);
            _eventRule = new RateLimiter.Rule(_cfg.EventBurst, _cfg.EventRefillPerSecond);
            _heartbeats.MissingAfter = TimeSpan.FromSeconds(_cfg.HeartbeatMissingSeconds);
            _movement = new MovementValidator(_cfg.Movement);
            _damage = new DamageValidator(_cfg.Damage);
            _explosions = new ExplosionValidator(_cfg.Explosions);
            _entities = new EntityValidator(_cfg.Entities);
            _state = new PlayerStateValidator { MaxHealth = _cfg.MaxHealth };
            _weaponBlacklist = new HashSet<uint>(_cfg.WeaponBlacklist.Select(Joaat.Hash));

            _dataDir = Path.Combine(GetResourcePath(_resource), "data");
            Directory.CreateDirectory(Path.Combine(_dataDir, "vision"));
            _bans = new BanStore(Path.Combine(_dataDir, "bans.json"));
            _vision = new AIVisionEvaluator(_cfg.Vision);
            _dashboard = new DashboardBridge(_cfg.Dashboard);

            RegisterEvents();
            RegisterExports();
            Tick += OnTick;

            Log($"started: {_bans.All.Count} bans, vision={(_vision.IsConfigured ? _cfg.Vision.Provider + "/" + _cfg.Vision.Model : "off")}, " +
                $"dashboard={(_dashboard.Enabled ? _cfg.Dashboard.Url : "off")}, dryRun={_cfg.DryRun}");
        }

        private void RegisterEvents()
        {
            EventHandlers["playerConnecting"] += new Action<Player, string, CallbackDelegate, IDictionary<string, object>>(OnPlayerConnecting);
            EventHandlers["playerDropped"] += new Action<Player, string>(OnPlayerDropped);
            EventHandlers["sentinel:hello"] += new Action<Player>(OnHello);
            EventHandlers[_hbEvent] += new Action<Player, object, string, string, string>(OnHeartbeat);
            EventHandlers[_ssUploadEvent] += new Action<Player, string, int, int, string>(OnScreenshotChunk);

            foreach (var name in _cfg.HoneypotEvents)
            {
                var eventName = name;
                EventHandlers[eventName] += new Action<Player>(p => OnHoneypot(p, eventName));
            }

            // OneSync game events.
            EventHandlers["weaponDamageEvent"] += new Action<object, object>(OnWeaponDamage);
            EventHandlers["explosionEvent"] += new Action<object, object>(OnExplosion);
            EventHandlers["entityCreating"] += new Action<int>(OnEntityCreating);
            EventHandlers["giveWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "giveWeaponEvent"));
            EventHandlers["removeWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeWeaponEvent"));
            EventHandlers["removeAllWeaponsEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeAllWeaponsEvent"));
            EventHandlers["clearPedTasksEvent"] += new Action<object, object>(OnClearPedTasks);
        }

        private void RegisterExports()
        {
            // exports.sentinel:GrantGrace(src, "heal" | "armor" | "teleport" | "godmode" | "invisible" | "noclip" | ..., ms)
            Exports.Add("GrantGrace", new Action<object, string, int>((src, kind, ms) => GrantGrace(ToId(src), kind, ms)));
            // exports.sentinel:Guard(src, "myresource:event") -> false when the player exceeds the event budget.
            Exports.Add("Guard", new Func<object, string, bool>((src, bucket) => Guard(ToId(src), bucket ?? "external")));
            Exports.Add("GetScore", new Func<object, double>(src => _ledger.ScoreOf(ToId(src))));
            Exports.Add("BanPlayer", new Action<object, string>((src, reason) => BanPlayer(ToId(src), "MANUAL", reason ?? "Banned by staff", "export")));
        }

        // ── Connection lifecycle ─────────────────────────────────────────────────────────────

        private void OnPlayerConnecting([FromSource] Player player, string name, CallbackDelegate setKickReason, IDictionary<string, object> deferrals)
        {
            var ids = IdentifiersOf(player.Handle);
            var ban = _bans.Find(ids);
            if (ban == null) return;

            var until = ban.ExpiresAt.HasValue ? ban.ExpiresAt.Value.ToString("yyyy-MM-dd HH:mm") + " UTC" : "permanent";
            var message = $"[Sentinel] You are banned. Reason: {ban.Reason} | Ban ID: {ban.Id} | Expires: {until}";
            ((CallbackDelegate)deferrals["defer"])();
            ((CallbackDelegate)deferrals["done"])(message);
            Log($"rejected banned connection {name} ({ban.Id})");
            _dashboard.Enqueue("connection_rejected", new Dictionary<string, object?> { ["name"] = name, ["banId"] = ban.Id });
        }

        private void OnPlayerDropped([FromSource] Player player, string reason)
        {
            int id = ToId(player.Handle);
            _heartbeats.End(id);
            _limiter.ForgetPlayer(id);
            _denied.RemoveWhere(k => k == id.ToString());
            _movement.Forget(id);
            _damage.Forget(id);
            _explosions.Forget(id);
            _entities.Forget(id);
            _state.Forget(id);
            _ledger.Forget(id);
            _lastCapture.TryRemove(id, out _);
            _dashboard.Enqueue("player_left", new Dictionary<string, object?> { ["id"] = id, ["name"] = player.Name, ["reason"] = reason });
        }

        private void OnHello([FromSource] Player player)
        {
            int id = ToId(player.Handle);
            if (!_limiter.TryConsume(id, "hello", _helloRule)) return;

            var existing = _heartbeats.Get(id);
            if (existing != null && existing.Sequence > 0)
            {
                // A second handshake after a working session means someone restarted the protocol,
                // e.g. a menu that killed the scanner and is trying to impersonate it.
                Punish(new Violation(id, "HB_INVALID", ViolationSource.Heartbeat, new Dictionary<string, object?> { ["reason"] = "rehandshake" }));
                return;
            }

            var (key, challenge) = _heartbeats.Begin(id);
            _movement.GrantGrace(id, TimeSpan.FromSeconds(30));
            _state.GrantGrace(id, "heal", TimeSpan.FromSeconds(30));
            _state.GrantGrace(id, "armor", TimeSpan.FromSeconds(30));

            var init = new Dictionary<string, object?>
            {
                ["k"] = key, ["c"] = challenge, ["hb"] = _hbEvent, ["ack"] = _ackEvent, ["gr"] = _graceEvent,
                ["sr"] = _ssRequestEvent, ["su"] = _ssUploadEvent, ["iv"] = _cfg.HeartbeatIntervalMs,
                ["wb"] = _cfg.WeaponBlacklist, ["rs"] = StartedResources(), ["mh"] = _cfg.MaxHealth,
                ["dm"] = _cfg.ExpectedDamageModifier,
            };
            player.TriggerEvent("sentinel:init", MiniJson.Serialize(init));
            _dashboard.Enqueue("player_joined", PlayerSnapshot(player));
        }

        // ── Heartbeat ────────────────────────────────────────────────────────────────────────

        private void OnHeartbeat([FromSource] Player player, object seq, string nonce, string ct, string mac)
        {
            int id = ToId(player.Handle);
            if (!Guard(id, "heartbeat")) return;

            var result = _heartbeats.Verify(id, seq, nonce, ct, mac);
            if (result.Status == HeartbeatStatus.NoSession) return;
            if (!result.Ok)
            {
                Punish(new Violation(id, "HB_INVALID", ViolationSource.Heartbeat, new Dictionary<string, object?>
                {
                    ["status"] = result.Status.ToString(), ["reason"] = result.Reason,
                }));
                return;
            }

            player.TriggerEvent(_ackEvent, result.NextChallenge);

            var flags = result.Payload.Arr("f");
            if (flags == null) return;
            foreach (var f in flags.Take(32).OfType<Dictionary<string, object?>>())
            {
                var code = f.Str("c") ?? "";
                var evidence = f.Obj("d") ?? new Dictionary<string, object?>();
                if (!ViolationCatalog.DefaultSeverity.ContainsKey(code))
                {
                    evidence = new Dictionary<string, object?> { ["unknownCode"] = code.Length > 48 ? code.Substring(0, 48) : code };
                    code = "CHK_ERROR";
                }
                Punish(new Violation(id, code, ViolationSource.Client, evidence));
            }
        }

        private void OnHoneypot([FromSource] Player player, string eventName)
        {
            int id = ToId(player.Handle);
            if (id <= 0) return; // server-side TriggerEvent of the same name, not a client
            Punish(new Violation(id, "NET_HONEYPOT", ViolationSource.Server, new Dictionary<string, object?> { ["event"] = eventName }));
        }

        // ── OneSync game events ──────────────────────────────────────────────────────────────

        private void OnWeaponDamage(object sender, object rawData)
        {
            int attacker = ToId(sender);
            if (attacker <= 0 || !(rawData is IDictionary<string, object> data)) return;
            if (!Guard(attacker, "weaponDamage")) { CancelEvent(); return; }

            int victimNetId = ToInt(Get(data, "hitGlobalId"));
            if (victimNetId == 0 && Get(data, "hitGlobalIds") is IList<object> many && many.Count > 0) victimNetId = ToInt(many[0]);
            int victimEntity = victimNetId != 0 ? NetworkGetEntityFromNetworkId(victimNetId) : 0;
            if (victimEntity == 0) return;

            int attackerPed = GetPlayerPed(attacker.ToString());
            int victimPlayer = IsPedAPlayer(victimEntity) ? NetworkGetEntityOwner(victimEntity) : 0;
            var hit = new WeaponHit
            {
                Attacker = attacker,
                VictimPlayer = victimPlayer,
                VictimNetId = victimNetId,
                WeaponHash = Joaat.FromSigned(ToLong(Get(data, "weaponType"))),
                Damage = ToInt(Get(data, "weaponDamage")),
                Headshot = ToInt(Get(data, "hitComponent")) == 20,
                WillKill = Get(data, "willKill") is bool wk && wk,
                AttackerPos = ToVec(GetEntityCoords(attackerPed)),
                AttackerHeading = GetEntityHeading(attackerPed),
                AttackerInVehicle = GetVehiclePedIsIn(attackerPed, false) != 0,
                VictimPos = ToVec(GetEntityCoords(victimEntity)),
                ImpactDir = Get(data, "hasImpactDir") is bool hasDir && hasDir
                    ? new Vec3(ToFloat(Get(data, "impactDirX")), ToFloat(Get(data, "impactDirY")), ToFloat(Get(data, "impactDirZ")))
                    : (Vec3?)null,
            };

            var found = _damage.Evaluate(hit);
            if (victimPlayer > 0 && hit.Damage > 0)
                _absorb.RecordHit(victimPlayer, GetEntityHealth(victimEntity), GetPedArmour(victimEntity), DateTime.UtcNow);

            bool cancel = false;
            foreach (var v in found)
            {
                if (v.Code == "WPN_DMG_MODIFIER" || v.Code == "WPN_RANGE") cancel = true;
                Punish(v);
            }
            if (cancel) CancelEvent();
        }

        private void OnExplosion(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;

            var info = new ExplosionInfo
            {
                Source = source,
                ExplosionType = ToInt(Get(data, "explosionType")),
                DamageScale = ToFloat(Get(data, "damageScale")),
                IsInvisible = Get(data, "isInvisible") is bool inv && inv,
                IsAudible = !(Get(data, "isAudible") is bool aud) || aud,
                CameraShake = ToFloat(Get(data, "cameraShake")),
                Position = new Vec3(ToFloat(Get(data, "posX")), ToFloat(Get(data, "posY")), ToFloat(Get(data, "posZ"))),
            };
            var (found, cancel) = _explosions.Evaluate(info);
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        private void OnEntityCreating(int handle)
        {
            int owner = NetworkGetEntityOwner(handle);
            if (owner <= 0) return;
            uint model = Joaat.FromSigned(GetEntityModel(handle));
            var kind = (EntityKind)GetEntityType(handle);
            bool scriptCreated = GetEntityPopulationType(handle) == 7; // POPTYPE_MISSION
            var (found, cancel) = _entities.Evaluate(owner, model, kind, scriptCreated, DateTime.UtcNow);
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        private void OnForbiddenWeaponEvent(object sender, string eventName)
        {
            // Under OneSync, legitimate weapon give/remove happens via server natives, never via these client events.
            CancelEvent();
            int source = ToId(sender);
            if (source > 0) Punish(new Violation(source, "WPN_GIVE_EVENT", ViolationSource.Server, new Dictionary<string, object?> { ["event"] = eventName }));
        }

        private void OnClearPedTasks(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;
            int pedNetId = ToInt(Get(data, "pedId"));
            int ped = pedNetId != 0 ? NetworkGetEntityFromNetworkId(pedNetId) : 0;
            // Clearing someone else's player ped (yanking them from vehicles) is a classic menu grief.
            if (ped != 0 && IsPedAPlayer(ped) && NetworkGetEntityOwner(ped) != source)
            {
                CancelEvent();
                Punish(new Violation(source, "NET_CLEAR_TASKS", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["target"] = NetworkGetEntityOwner(ped), ["immediately"] = Get(data, "immediately"),
                }));
            }
        }

        // ── Screenshots ──────────────────────────────────────────────────────────────────────

        private void OnScreenshotChunk([FromSource] Player player, string captureId, int index, int total, string data)
        {
            int id = ToId(player.Handle);
            var r = _screenshots.AddChunk(id, captureId, index, total, data, out var completed);
            if (r == ScreenshotAssembler.ChunkResult.Unavailable)
                Log($"screenshot unavailable for {player.Name}: screenshot-basic is not running");
            if (r != ScreenshotAssembler.ChunkResult.Complete || completed == null) return;

            try { File.WriteAllBytes(Path.Combine(_dataDir, "vision", completed.Id + ".jpg"), completed.Jpeg); }
            catch (Exception ex) { Log("could not save screenshot: " + ex.Message); }

            if (!_vision.IsConfigured)
            {
                _visionResults.Enqueue((completed, new VisionVerdict { Verdict = VisionVerdictKind.Error, Error = "vision not configured" }));
                return;
            }
            var context = completed.Reason;
            // Off the main thread; the result is drained in the tick.
            System.Threading.Tasks.Task.Run(async () =>
            {
                var verdict = await _vision.EvaluateAsync(completed.Jpeg, context).ConfigureAwait(false);
                _visionResults.Enqueue((completed, verdict));
            });
        }

        private void RequestScreenshot(int player, string reason)
        {
            var now = DateTime.UtcNow;
            if (_screenshots.IsPending(player)) return;
            if (_lastCapture.TryGetValue(player, out var last) && (now - last).TotalSeconds < _cfg.Vision.CooldownSeconds) return;
            _lastCapture[player] = now;
            var p = Players[player];
            if (p == null) return;
            var captureId = _screenshots.Begin(player, reason);
            p.TriggerEvent(_ssRequestEvent, captureId);
        }

        // ── Helpers ──────────────────────────────────────────────────────────────────────────

        private bool Guard(int player, string bucket)
        {
            if (player <= 0) return true;
            if (_limiter.TryConsume(player, "all", _eventRule)) return true;
            // One denied event is noise (lag burst); a sustained stream of denials is a flood: drop the client.
            int denied = _denied.Add(player.ToString(), DateTime.UtcNow, TimeSpan.FromSeconds(10));
            if (denied == 1 || denied == _cfg.FloodDeniedPer10s)
            {
                var code = denied >= _cfg.FloodDeniedPer10s ? "NET_FLOOD" : "NET_RATE";
                Punish(new Violation(player, code, ViolationSource.Server, new Dictionary<string, object?> { ["bucket"] = bucket, ["denied10s"] = denied }));
            }
            return false;
        }

        private void GrantGrace(int player, string kind, int ms)
        {
            if (player <= 0 || string.IsNullOrEmpty(kind)) return;
            var duration = TimeSpan.FromMilliseconds(Math.Max(0, Math.Min(ms, 600_000)));
            if (kind == "teleport" || kind == "noclip") _movement.GrantGrace(player, duration);
            _state.GrantGrace(player, kind, duration);
            Players[player]?.TriggerEvent(_graceEvent, kind, ms);
        }

        private List<string> StartedResources()
        {
            var list = new List<string>();
            int n = GetNumResources();
            for (int i = 0; i < n; i++)
            {
                var name = GetResourceByFindIndex(i);
                if (!string.IsNullOrEmpty(name) && GetResourceState(name) == "started") list.Add(name);
            }
            return list;
        }

        private static List<string> IdentifiersOf(string handle)
        {
            var ids = new List<string>();
            int n = GetNumPlayerIdentifiers(handle);
            for (int i = 0; i < n; i++) ids.Add(GetPlayerIdentifier(handle, i));
            int t = GetNumPlayerTokens(handle);
            for (int i = 0; i < t; i++) ids.Add("token:" + GetPlayerToken(handle, i));
            return ids;
        }

        private static object? Get(IDictionary<string, object> d, string key) => d.TryGetValue(key, out var v) ? v : null;
        private static int ToId(object? o) { try { return Convert.ToInt32(o); } catch { return 0; } }
        private static int ToInt(object? o) { try { return o == null ? 0 : Convert.ToInt32(o); } catch { return 0; } }
        private static long ToLong(object? o) { try { return o == null ? 0 : Convert.ToInt64(o); } catch { return 0; } }
        private static float ToFloat(object? o) { try { return o == null ? 0 : Convert.ToSingle(o); } catch { return 0; } }
        private static Vec3 ToVec(Vector3 v) => new Vec3(v.X, v.Y, v.Z);

        private static void Log(string message) => Debug.WriteLine("[sentinel] " + message);
    }
}
