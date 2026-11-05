using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using CitizenFX.Core;
using JcksAnticheat.Core.Bans;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Dashboard;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Heartbeat;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Validation;
using JcksAnticheat.Core.Vision;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript : BaseScript
    {
        private readonly string _resource;
        private readonly AnticheatConfig _cfg;
        private readonly ViolationLedger _ledger;
        private readonly RateLimiter _limiter = new RateLimiter();
        private RateLimiter.Rule _eventRule;
        private readonly RateLimiter.Rule _helloRule = new RateLimiter.Rule(3, 0.05);
        private readonly SlidingCounter _denied = new SlidingCounter();
        private readonly HeartbeatManager _heartbeats = new HeartbeatManager();
        private readonly MovementValidator _movement;
        private readonly DamageValidator _damage;
        private readonly AbsorbTracker _absorb = new AbsorbTracker();
        private readonly ExplosionValidator _explosions;
        private readonly GameEventValidator _gameEvents;
        private readonly VehicleOwnership _vehicles = new VehicleOwnership();
        private readonly IntegrationLearning _learning = new IntegrationLearning();
        private IntegrationPolicy _integrations = new IntegrationPolicy();
        private readonly RateLimiter.Rule _graceRule = new RateLimiter.Rule(30, 0.5);
        private readonly EntityValidator _entities;
        private readonly PlayerStateValidator _state;
        private readonly StateConsistencyValidator _consistency = new StateConsistencyValidator();
        private readonly PlayerFlagsValidator _flags = new PlayerFlagsValidator();
        private readonly MassKillTracker _massKills;
        private readonly VpnChecker _vpn;
        private readonly ScopeTracker _scope = new ScopeTracker();
        private readonly JcksAnticheat.Core.Logging.ReportThrottle _throttle = new JcksAnticheat.Core.Logging.ReportThrottle();
        private ConfigHistory _history = null!;
        private readonly JcksAnticheat.Core.Logging.RecentViolations _recent = new JcksAnticheat.Core.Logging.RecentViolations();
        private readonly JcksAnticheat.Core.Logging.StaffAlerts _staffAlerts;
        private readonly BanStore _bans;
        private readonly ScreenshotAssembler _screenshots = new ScreenshotAssembler();
        private readonly AIVisionEvaluator _vision;
        private readonly DashboardBridge _dashboard;
        private readonly JcksAnticheat.Core.Logging.DiscordWebhook _discord;
        private HashSet<uint> _weaponBlacklist;
        private readonly string _dataDir;

        private readonly string _hbEvent = HeartbeatManager.RandomEventName();
        private readonly string _ackEvent = HeartbeatManager.RandomEventName();
        private readonly string _graceEvent = HeartbeatManager.RandomEventName();
        private readonly string _counterEvent = HeartbeatManager.RandomEventName();
        private readonly string _ssRequestEvent = HeartbeatManager.RandomEventName();
        private readonly string _ssUploadEvent = HeartbeatManager.RandomEventName();
        private readonly string _resourceEvent = HeartbeatManager.RandomEventName();

        private readonly ConcurrentQueue<(ScreenshotAssembler.Completed shot, VisionVerdict verdict)> _visionResults =
            new ConcurrentQueue<(ScreenshotAssembler.Completed, VisionVerdict)>();
        private readonly ConcurrentDictionary<int, DateTime> _lastCapture = new ConcurrentDictionary<int, DateTime>();

        public AnticheatScript()
        {
            _resource = GetCurrentResourceName();
            var raw = LoadResourceFile(_resource, "config.json");
            _cfg = AnticheatConfig.Parse(string.IsNullOrWhiteSpace(raw) ? "{}" : raw);

            _ledger = new ViolationLedger(_cfg.Scoring);
            _eventRule = new RateLimiter.Rule(_cfg.EventBurst, _cfg.EventRefillPerSecond);
            _heartbeats.MissingAfter = TimeSpan.FromSeconds(_cfg.HeartbeatMissingSeconds);
            _heartbeats.HandshakeTimeout = TimeSpan.FromSeconds(_cfg.HandshakeTimeoutSeconds);
            _movement = new MovementValidator(_cfg.Movement);
            _damage = new DamageValidator(_cfg.Damage);
            _massKills = new MassKillTracker(_cfg.Damage);
            _vpn = new VpnChecker(_cfg.Vpn);
            _staffAlerts = new JcksAnticheat.Core.Logging.StaffAlerts(_cfg.StaffAlerts);
            _explosions = new ExplosionValidator(_cfg.Explosions);
            _entities = new EntityValidator(_cfg.Entities);
            _state = new PlayerStateValidator { MaxHealth = _cfg.MaxHealth };
            ConfigureFlags();
            _weaponBlacklist = new HashSet<uint>(_cfg.WeaponBlacklist.Select(Joaat.Hash));
            _gameEvents = new GameEventValidator(_cfg.GameEvents, () => _weaponBlacklist);

            _dataDir = Path.Combine(GetResourcePath(_resource), "data");
            Directory.CreateDirectory(Path.Combine(_dataDir, "vision"));
            _history = new ConfigHistory(Path.Combine(_dataDir, "config-history"));
            _bans = new BanStore(Path.Combine(_dataDir, "bans.json"));
            _vision = new AIVisionEvaluator(_cfg.Vision);
            _dashboard = new DashboardBridge(_cfg.Dashboard);
            _discord = new JcksAnticheat.Core.Logging.DiscordWebhook(_cfg.Discord);

            RegisterEvents();
            foreach (var p in Players) OnPlayerJoining(p, "");
            RegisterExports();
            ApplyServerThresholds();
            InitLicense();
            RebuildIntegrations();
            RegisterSettings();
            RegisterAntiDump();
            Tick += OnTick;

            Log($"started: {_bans.All.Count} bans, vision={(_vision.IsConfigured ? _cfg.Vision.Provider + "/" + _cfg.Vision.Model : "off")}, " +
                $"dashboard={(_dashboard.Enabled ? _cfg.Dashboard.Url : "off")}, dryRun={_cfg.DryRun}");
        }

        private void RegisterEvents()
        {
            EventHandlers["playerConnecting"] += new Action<Player, string, CallbackDelegate, IDictionary<string, object>>(OnPlayerConnecting);
            EventHandlers["playerDropped"] += new Action<Player, string>(OnPlayerDropped);
            EventHandlers["playerJoining"] += new Action<Player, string>(OnPlayerJoining);
            EventHandlers["_chat:messageEntered"] += new Action<Player, object, object, object>(OnChatMessage);
            EventHandlers["chatMessage"] += new Action<int, string, string>(OnLocalChatMessage);
            EventHandlers["onServerResourceStart"] += new Action<string>(OnServerResourceStart);
            EventHandlers["jcks_anticheat:hello"] += new Action<Player>(OnHello);
            EventHandlers[_hbEvent] += new Action<Player, object, string, string, string>(OnHeartbeat);
            EventHandlers[_ssUploadEvent] += new Action<Player, string, int, int, string>(OnScreenshotChunk);

            RegisterHoneypots();
            RegisterProtectedEvents();

            EventHandlers["weaponDamageEvent"] += new Action<object, object>(OnWeaponDamage);
            EventHandlers["explosionEvent"] += new Action<object, object>(OnExplosion);
            EventHandlers["entityCreating"] += new Action<int>(OnEntityCreating);
            EventHandlers["entityCreated"] += new Action<int>(OnEntityCreated);
            EventHandlers["entityRemoved"] += new Action<int>(h => _vehicles.Untrack(NetworkGetNetworkIdFromEntity(h)));
            EventHandlers["giveWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "giveWeaponEvent"));
            EventHandlers["removeWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeWeaponEvent"));
            EventHandlers["removeAllWeaponsEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeAllWeaponsEvent"));
            EventHandlers["clearPedTasksEvent"] += new Action<object, object>(OnClearPedTasks);
            EventHandlers["givePedScriptedTaskEvent"] += new Action<object, object>(OnGivePedTask);
            EventHandlers["onPedDeath"] += new Action<object, object, object>(OnPedDeath);
            EventHandlers["playerEnteredScope"] += new Action<object>(d => { if (d is IDictionary<string, object> m) _scope.Entered(ToInt(Get(m, "player")), ToInt(Get(m, "for"))); });
            EventHandlers["playerLeftScope"] += new Action<object>(d => { if (d is IDictionary<string, object> m) _scope.Left(ToInt(Get(m, "player")), ToInt(Get(m, "for")), DateTime.UtcNow); });
            EventHandlers["startProjectileEvent"] += new Action<object, object>(OnStartProjectile);
            EventHandlers["fireEvent"] += new Action<object, object>(OnFireEvent);
            EventHandlers["ptFxEvent"] += new Action<object, object>(OnPtfxEvent);
        }

        private void RegisterExports()
        {
            Exports.Add("GrantGrace", new Action<object, string, int>((src, kind, ms) => GrantGrace(ToId(src), kind, ms)));
            Exports.Add("Guard", new Func<object, string, bool>((src, bucket) => Guard(ToId(src), bucket ?? "external")));
            Exports.Add("GetScore", new Func<object, double>(src => _ledger.ScoreOf(ToId(src))));
            Exports.Add("CheckEvent", new Func<object, string, bool>((src, ev) => CheckEvent(ToId(src), ev ?? "")));
            Exports.Add("ReportViolation", new Func<object, string, object, bool>(ReportExternal));
            Exports.Add("BanPlayer", new Action<object, string>((src, reason) => BanPlayer(ToId(src), "MANUAL", reason ?? "Banned by staff", "export")));
        }


        private void OnPlayerConnecting([FromSource] Player player, string name, CallbackDelegate setKickReason, IDictionary<string, object> deferrals)
        {
            var nameProblem = NameFilter.Check(name, _cfg.BlockHtmlNames, _cfg.NameBlacklist);
            if (nameProblem != null)
            {
                ((CallbackDelegate)deferrals["defer"])();
                ((CallbackDelegate)deferrals["done"])(Msg(_cfg.Messages.NameRejected, null, nameProblem, null, null, name));
                Log($"refused connection: name '{name}' ({nameProblem})");
                _dashboard.Enqueue("connection_rejected", new Dictionary<string, object?> { ["name"] = name, ["banId"] = "name filter" });
                return;
            }

            var ids = IdentifiersOf(player.Handle);
            var ban = _bans.Find(ids);
            if (ban == null)
            {
                if (_cfg.Vpn.Enabled && !_vpn.Allowed(ids)) CheckVpn(name, ids, deferrals);
                return;
            }

            if (_cfg.LinkBanIdentifiers)
            {
                var added = _bans.Link(ban, ids);
                if (added.Count > 0)
                {
                    Log($"ban {ban.Id}: linked {added.Count} new identifier(s) from {name}");
                    _dashboard.Enqueue("ban_linked", new Dictionary<string, object?> { ["id"] = ban.Id, ["name"] = name, ["added"] = added.Cast<object?>().ToList() });
                }
            }
            var message = Msg(_cfg.Messages.Banned, ban.Code, ban.Reason, ban.Id, ExpiryText(ban.ExpiresAt), name);
            ((CallbackDelegate)deferrals["defer"])();
            ((CallbackDelegate)deferrals["done"])(message);
            Log($"rejected banned connection {name} ({ban.Id})");
            _dashboard.Enqueue("connection_rejected", new Dictionary<string, object?> { ["name"] = name, ["banId"] = ban.Id });
        }

        private async void CheckVpn(string name, List<string> ids, IDictionary<string, object> deferrals)
        {
            var ip = ids.FirstOrDefault(i => i.StartsWith("ip:", StringComparison.Ordinal))?.Substring(3);
            if (string.IsNullOrEmpty(ip)) return;
            ((CallbackDelegate)deferrals["defer"])();
            ((CallbackDelegate)deferrals["update"])("[JCKS Anticheat] Checking your connection…");
            bool? vpn = null;
            try { vpn = await _vpn.IsVpnAsync(ip!, DateTime.UtcNow); }
            catch (Exception ex) { Log("vpn check failed: " + ex.Message); }
            if (vpn == true)
            {
                ((CallbackDelegate)deferrals["done"])(Msg(_cfg.Messages.VpnRejected, "VPN", "VPN or proxy", null, null, name));
                Log($"refused connection: {name} uses a VPN or proxy");
                _dashboard.Enqueue("connection_rejected", new Dictionary<string, object?> { ["name"] = name, ["banId"] = "vpn check" });
                return;
            }
            if (vpn == null) Log($"vpn check for {name} unavailable; letting them in");
            ((CallbackDelegate)deferrals["done"])();
        }

        private void OnServerResourceStart(string name)
        {
            if (string.IsNullOrEmpty(name) || name == _resource) return;
            RebuildIntegrations();
            foreach (var p in Players)
                if (_heartbeats.HasSession(ToId(p.Handle))) p.TriggerEvent(_resourceEvent, name);
        }

        private void OnChatMessage([FromSource] Player player, object author, object color, object message)
        {
            if (!_cfg.ChatSpoofCheck) return;
            int id = ToId(player.Handle);
            if (id <= 0) return;
            var claimed = author?.ToString() ?? "";
            if (claimed.Length == 0 || claimed == player.Name) return;
            CancelEvent();
            lock (_chatSpoofAt) _chatSpoofAt[id] = DateTime.UtcNow;
            Punish(new Violation(id, "NET_CHAT_SPOOF", ViolationSource.Server, new Dictionary<string, object?>
            {
                ["claimed"] = claimed.Length > 48 ? claimed.Substring(0, 48) : claimed,
            }));
        }

        private void OnLocalChatMessage(int source, string author, string message)
        {
            lock (_chatSpoofAt)
            {
                if (!_chatSpoofAt.TryGetValue(source, out var at)) return;
                _chatSpoofAt.Remove(source);
                if (DateTime.UtcNow - at < TimeSpan.FromSeconds(3)) CancelEvent();
            }
        }

        private void OnPlayerJoining([FromSource] Player player, string oldId)
        {
            int id = ToId(player.Handle);
            if (id <= 0) return;
            _ledger.Restore(id, LicenseOf(player.Handle));
            _movement.GrantGrace(id, TimeSpan.FromSeconds(90));
            _state.GrantGrace(id, "heal", TimeSpan.FromSeconds(90));
            _state.GrantGrace(id, "armor", TimeSpan.FromSeconds(90));
        }

        private void OnPlayerDropped([FromSource] Player player, string reason)
        {
            int id = ToId(player.Handle);
            _heartbeats.End(id);
            _limiter.ForgetPlayer(id);
            _denied.RemoveWhere(k => k == id.ToString());
            _protectedCounter.RemoveWhere(k => k.StartsWith(id + ":", StringComparison.Ordinal));
            _movement.Forget(id);
            _damage.Forget(id);
            _explosions.Forget(id);
            _gameEvents.Forget(id);
            _vehicles.ForgetPlayer(id);
            _entities.Forget(id);
            _state.Forget(id);
            _flags.Forget(id);
            _massKills.Forget(id);
            _recent.Forget(id);
            _throttle.Forget(id);
            _scope.Forget(id);
            _staffAlerts.Forget(id);
            _consistency.Forget(id);
            ForgetAntiDump(id);
            ForgetDeferred(id);
            _removing.TryRemove(id, out _);
            _ledger.Park(id, LicenseOf(player.Handle));
            _lastCapture.TryRemove(id, out _);
            _dashboard.Enqueue("player_left", new Dictionary<string, object?> { ["id"] = id, ["name"] = player.Name, ["reason"] = reason });
        }

        private void OnHello([FromSource] Player player)
        {
            if (!_licensed) return;
            int id = ToId(player.Handle);
            if (!_limiter.TryConsume(id, "hello", _helloRule)) return;

            var existing = _heartbeats.Get(id);
            if (existing != null && existing.Sequence > 0)
            {
                Punish(new Violation(id, "HB_INVALID", ViolationSource.Heartbeat, new Dictionary<string, object?> { ["reason"] = "rehandshake" }));
                return;
            }

            var (key, challenge) = _heartbeats.Begin(id);
            _movement.GrantGrace(id, TimeSpan.FromSeconds(30));
            _state.GrantGrace(id, "heal", TimeSpan.FromSeconds(30));
            _state.GrantGrace(id, "armor", TimeSpan.FromSeconds(30));

            var init = new Dictionary<string, object?>
            {
                ["k"] = key, ["c"] = challenge, ["hb"] = _hbEvent, ["ack"] = _ackEvent, ["gr"] = _graceEvent, ["ce"] = _counterEvent,
                ["sr"] = _ssRequestEvent, ["su"] = _ssUploadEvent, ["ru"] = _resourceEvent, ["iv"] = _cfg.HeartbeatIntervalMs,
                ["wb"] = _cfg.WeaponBlacklist, ["rs"] = StartedResources(), ["mh"] = _cfg.MaxHealth,
                ["dm"] = _cfg.ExpectedDamageModifier, ["ig"] = _cfg.Scoring.Ignore.ToList(),
                ["mw"] = _cfg.MaxWeapons, ["tb"] = _cfg.TextureBlacklist,
                ["se"] = _settingsEvent, ["po"] = _panelOpenEvent,
            };
            foreach (var kv in ClientSettings()) init[kv.Key] = kv.Value;
            init["bp"] = _cfg.AdminAce.Any(ace => IsPlayerAceAllowed(player.Handle, ace));
            init["bc"] = ViolationCatalog.DefaultSeverity.Keys.Where(code => _cfg.AdminAce.Any(ace => IsPlayerAceAllowed(player.Handle, ace + "." + code))).ToList();
            player.TriggerEvent("jcks_anticheat:init", MiniJson.Serialize(init));
            ServePendingAntiDump(player, id);
            _dashboard.Enqueue("player_joined", PlayerSnapshot(player));
        }


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
            CheckReportedState(player, id, result.Payload.Obj("st"));
            ProcessIntegrationUses(id, result.Payload.Arr("u"));

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
                if (code == "EXE_RESOURCE_STOP" && GetResourceState(evidence.Str("r") ?? "") != "started") continue;
                Punish(new Violation(id, code, ViolationSource.Client, evidence));
            }
        }

        private void ProcessIntegrationUses(int id, List<object?>? uses)
        {
            if (uses == null) return;
            var now = DateTime.UtcNow;
            foreach (var u in uses.Take(32).OfType<Dictionary<string, object?>>())
            {
                var resource = u.Str("r") ?? "";
                var kind = u.Str("k") ?? "";
                if (_cfg.Integrations.Learning) _learning.Record(resource, kind);
                bool listed = u.Bool("a") == true && _integrations.Allows(resource, kind);
                bool reported = _cfg.Integrations.ServerTrustReportedResources && resource != _resource
                                && Behaviours.IsKnown(kind) && kind != "*" && GetResourceState(resource) == "started";
                if (!listed && !reported) continue;
                if (!_limiter.TryConsume(id, "grace:" + kind, _graceRule)) continue;
                var duration = TimeSpan.FromMilliseconds(listed ? _cfg.Integrations.GraceMs : 3000);
                if (kind == "teleport" || kind == "noclip") _movement.GrantGrace(id, duration, now);
                _state.GrantGrace(id, kind, duration, now);
                RecordGrant(id, kind, now);
            }
        }

        private void ApplyServerThresholds()
        {
            var t = _cfg.ServerThresholds;
            _consistency.PositionTolerance = (float)t["statePositionTolerance"];
            _consistency.SpeedToleranceSeconds = (float)t["stateSpeedToleranceSeconds"];
            _consistency.HealthTolerance = (int)t["stateHealthTolerance"];
            _consistency.ArmorTolerance = (int)t["stateArmorTolerance"];
            _consistency.StreakToReport = Math.Max(1, (int)t["stateStreak"]);
            _absorb.Threshold = Math.Max(1, (int)t["absorbHits"]);
            _absorb.Window = TimeSpan.FromSeconds(t["absorbWindowSeconds"]);
            _state.HealthJump = (int)t["serverHealthJump"];
            _state.ArmorJump = (int)t["serverArmorJump"];
        }

        private void RebuildIntegrations()
        {
            var presets = IntegrationPolicy.ParsePresets(LoadResourceFile(_resource, "integrations.presets.json"));
            _integrations = IntegrationPolicy.Build(_cfg.Integrations, presets, r => GetResourceState(r) != "missing");
        }

        private void CheckReportedState(Player player, int id, Dictionary<string, object?>? st)
        {
            if (st == null || !(st.Arr("p") is List<object?> p) || p.Count < 3) return;
            int ped = GetPlayerPed(player.Handle);
            if (ped == 0) return;
            int serverHealth = GetEntityHealth(ped);
            var now = DateTime.UtcNow;
            int veh = GetVehiclePedIsIn(ped, false);
            var vel = GetEntityVelocity(veh != 0 ? veh : ped);
            bool skip = serverHealth <= 100 || _state.HasGrace(id, "heal", now) || _state.HasGrace(id, "armor", now)
                        || _state.HasGrace(id, "teleport", now) || _state.HasGrace(id, "noclip", now);
            var v = _consistency.Evaluate(id,
                (int)(st.Num("h") ?? serverHealth), (int)(st.Num("a") ?? 0),
                new Vec3(ToFloat(p[0]), ToFloat(p[1]), ToFloat(p[2])),
                serverHealth, GetPedArmour(ped), ToVec(GetEntityCoords(ped)),
                (float)Math.Sqrt(vel.X * vel.X + vel.Y * vel.Y + vel.Z * vel.Z), skip);
            if (v != null) Punish(v);
        }

        private readonly HashSet<string> _honeypotsRegistered = new HashSet<string>(StringComparer.Ordinal);
        private readonly HashSet<string> _protectedRegistered = new HashSet<string>(StringComparer.Ordinal);
        private readonly SlidingCounter _protectedCounter = new SlidingCounter();

        private Dictionary<string, List<EventZone>> _zones = new Dictionary<string, List<EventZone>>(StringComparer.Ordinal);
        private readonly SlidingCounter _zoneReports = new SlidingCounter();
        private readonly Dictionary<int, DateTime> _chatSpoofAt = new Dictionary<int, DateTime>();

        private void RegisterProtectedEvents()
        {
            _zones = EventZones.Compile(_cfg.EventZones);
            foreach (var name in _cfg.ProtectedEvents.Keys.Concat(_zones.Keys))
            {
                if (!_protectedRegistered.Add(name)) continue;
                var eventName = name;
                EventHandlers[eventName] += new Action<Player>(p => OnProtectedEvent(p, eventName));
            }
        }

        private bool OutsideZone(int id, string eventName, out float distance)
        {
            distance = 0;
            if (!_zones.TryGetValue(eventName, out var zones)) return false;
            var p = Players[id];
            int ped = p != null ? GetPlayerPed(p.Handle) : 0;
            if (ped == 0) return false;
            return !EventZones.Inside(zones, ToVec(GetEntityCoords(ped)), out distance);
        }

        private bool CheckEvent(int id, string eventName)
        {
            if (id <= 0 || string.IsNullOrEmpty(eventName)) return true;
            if (_cfg.ProtectedEvents.TryGetValue(eventName, out var perMinute)
                && _protectedCounter.Count(id + ":" + eventName, DateTime.UtcNow, TimeSpan.FromMinutes(1)) > perMinute) return false;
            return !OutsideZone(id, eventName, out _);
        }

        private void OnProtectedEvent([FromSource] Player player, string eventName)
        {
            int id = ToId(player.Handle);
            if (id <= 0) return;
            if (OutsideZone(id, eventName, out var distance))
            {
                CancelEvent();
                if (_zoneReports.Add(id + ":" + eventName, DateTime.UtcNow, TimeSpan.FromSeconds(30)) == 1)
                    Punish(new Violation(id, "NET_EVENT_ZONE", ViolationSource.Server, new Dictionary<string, object?>
                    {
                        ["event"] = eventName, ["metresOutside"] = Math.Round(distance, 1),
                    }));
            }
            if (!_cfg.ProtectedEvents.TryGetValue(eventName, out var perMinute)) return;
            int n = _protectedCounter.Add(id + ":" + eventName, DateTime.UtcNow, TimeSpan.FromMinutes(1));
            if (n <= perMinute) return;
            CancelEvent();
            if (n == perMinute + 1 || n % 50 == 0)
                Punish(new Violation(id, "NET_EVENT_SPAM", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["event"] = eventName, ["perMinute"] = n, ["limit"] = perMinute,
                }));
        }

        private void RegisterHoneypots()
        {
            foreach (var name in _cfg.HoneypotEvents)
            {
                if (string.IsNullOrWhiteSpace(name) || !_honeypotsRegistered.Add(name)) continue;
                var eventName = name;
                EventHandlers[eventName] += new Action<Player>(p => OnHoneypot(p, eventName));
            }
        }

        private void OnHoneypot([FromSource] Player player, string eventName)
        {
            if (!_cfg.HoneypotEvents.Contains(eventName)) return;
            int id = ToId(player.Handle);
            if (id <= 0) return;
            Punish(new Violation(id, "NET_HONEYPOT", ViolationSource.Server, new Dictionary<string, object?> { ["event"] = eventName }));
        }


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
            if (victimPlayer > 0 && victimPlayer != attacker && _scope.KnownOutOfScope(attacker, victimPlayer, DateTime.UtcNow))
                found.Add(new Violation(attacker, "WPN_OUT_OF_SCOPE", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["victim"] = victimPlayer, ["dmg"] = hit.Damage, ["serverObserved"] = true,
                }));
            if (victimPlayer > 0 && hit.Damage > 0)
                _absorb.RecordHit(victimPlayer, GetEntityHealth(victimEntity), GetPedArmour(victimEntity), DateTime.UtcNow);

            bool cancel = false;
            foreach (var v in found)
            {
                if (v.Code == "WPN_DMG_MODIFIER" || v.Code == "WPN_RANGE" || v.Code == "WPN_OUT_OF_SCOPE") cancel = true;
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
                OwnerPlayer = OwnerPlayerOf(ToInt(Get(data, "ownerNetId"))),
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
            bool scriptCreated = GetEntityPopulationType(handle) == 7;
            var (found, cancel) = _entities.Evaluate(owner, model, kind, scriptCreated, DateTime.UtcNow);
            var unknown = EntityScriptCheck.Evaluate(owner, scriptCreated, kind == EntityKind.Ped && IsPedAPlayer(handle), GetEntityScript(handle), model, kind);
            if (unknown != null)
            {
                found.Add(unknown);
                if (_cfg.Entities.BlockUnknownScript && CountermeasureOn(unknown.Code) && !_cfg.DryRun) cancel = true;
            }
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        private void OnEntityCreated(int handle)
        {
            if (GetEntityType(handle) != (int)EntityKind.Vehicle || GetEntityPopulationType(handle) != 7) return;
            int owner = NetworkGetEntityOwner(handle);
            if (owner > 0) _vehicles.Track(NetworkGetNetworkIdFromEntity(handle), owner);
        }

        private void OnForbiddenWeaponEvent(object sender, string eventName)
        {
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
            if (ped != 0 && IsPedAPlayer(ped) && NetworkGetEntityOwner(ped) != source)
            {
                CancelEvent();
                Punish(new Violation(source, "NET_CLEAR_TASKS", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["target"] = NetworkGetEntityOwner(ped), ["immediately"] = Get(data, "immediately"),
                }));
            }
        }

        private bool ReportExternal(object src, string code, object details)
        {
            Dictionary<string, object?>? evidence = null;
            if (details is IDictionary<string, object> map) evidence = map.ToDictionary(k => k.Key, k => (object?)k.Value);
            else if (details != null) evidence = new Dictionary<string, object?> { ["details"] = details.ToString() };
            var v = ExternalReport.Create(ToId(src), code, GetInvokingResource(), evidence, DateTime.UtcNow);
            if (v == null) return false;
            Punish(v);
            return true;
        }

        private void OnPedDeath(object rawPed, object rawAttacker, object rawWeapon)
        {
            int ped = ToInt(rawPed), attacker = ToInt(rawAttacker);
            if (ped == 0 || attacker == 0 || !IsPedAPlayer(ped)) return;
            int killerPed = attacker;
            if (GetEntityType(attacker) == (int)EntityKind.Vehicle) killerPed = GetPedInVehicleSeat(attacker, -1);
            if (killerPed == 0 || !IsPedAPlayer(killerPed)) return;
            int killer = NetworkGetEntityOwner(killerPed), victim = NetworkGetEntityOwner(ped);
            var v = _massKills.RecordKill(killer, victim, unchecked((uint)ToLong(rawWeapon)), DateTime.UtcNow);
            if (v != null) Punish(v);
        }

        private void OnGivePedTask(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;
            int pedNetId = ToInt(Get(data, "entityNetId"));
            int ped = pedNetId != 0 ? NetworkGetEntityFromNetworkId(pedNetId) : 0;
            if (ped == 0 || !IsPedAPlayer(ped) || NetworkGetEntityOwner(ped) == source) return;
            CancelEvent();
            Punish(new Violation(source, "NET_GIVE_TASK", ViolationSource.Server, new Dictionary<string, object?>
            {
                ["target"] = NetworkGetEntityOwner(ped), ["task"] = Get(data, "taskId"),
            }));
        }

        private static int OwnerPlayerOf(int netId)
        {
            if (netId == 0) return 0;
            int entity = NetworkGetEntityFromNetworkId(netId);
            if (entity == 0) return 0;
            if (IsPedAPlayer(entity)) return NetworkGetEntityOwner(entity);
            if (GetEntityType(entity) == (int)EntityKind.Vehicle)
            {
                int driver = GetPedInVehicleSeat(entity, -1);
                if (driver != 0 && IsPedAPlayer(driver)) return NetworkGetEntityOwner(driver);
            }
            return 0;
        }

        private static int PlayerOfNetEntity(int netId)
        {
            if (netId == 0) return 0;
            int entity = NetworkGetEntityFromNetworkId(netId);
            return entity != 0 && IsPedAPlayer(entity) ? NetworkGetEntityOwner(entity) : 0;
        }

        private void OnStartProjectile(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;
            if (!Guard(source, "projectile")) { CancelEvent(); return; }
            int ped = GetPlayerPed(source.ToString());
            int ownerNet = ToInt(Get(data, "ownerId"));
            int owner = ownerNet != 0 ? NetworkGetEntityFromNetworkId(ownerNet) : 0;
            int shooterVeh = GetVehiclePedIsIn(ped, false);
            var (found, cancel) = _gameEvents.Projectile(new ProjectileInfo
            {
                Source = source,
                WeaponHash = Joaat.FromSigned(ToLong(Get(data, "weaponHash"))),
                Origin = new Vec3(ToFloat(Get(data, "initialPositionX")), ToFloat(Get(data, "initialPositionY")), ToFloat(Get(data, "initialPositionZ"))),
                ShooterPos = ToVec(GetEntityCoords(ped)),
                ShooterInVehicle = shooterVeh != 0,
                OwnerIsShooter = owner == 0 || owner == ped || owner == shooterVeh || !IsPedAPlayer(owner) || NetworkGetEntityOwner(owner) == source,
            });
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        private void OnFireEvent(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;
            if (!Guard(source, "fire")) { CancelEvent(); return; }
            var fires = Get(data, "fires") as IList<object> ?? new List<object>();
            int target = 0;
            foreach (var f in fires.OfType<IDictionary<string, object>>())
            {
                if (Get(f, "isEntity") is bool isEntity && isEntity)
                {
                    int p = PlayerOfNetEntity(ToInt(Get(f, "entityGlobalId")));
                    if (p > 0 && p != source) { target = p; break; }
                }
            }
            var (found, cancel) = _gameEvents.Fire(new FireInfo { Source = source, TargetPlayer = target, Count = Math.Max(1, fires.Count) });
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        private void OnPtfxEvent(object sender, object rawData)
        {
            int source = ToId(sender);
            if (source <= 0 || !(rawData is IDictionary<string, object> data)) return;
            if (!Guard(source, "ptfx")) { CancelEvent(); return; }
            int target = Get(data, "isOnEntity") is bool on && on ? PlayerOfNetEntity(ToInt(Get(data, "entityNetId"))) : 0;
            var (found, cancel) = _gameEvents.Ptfx(new PtfxInfo { Source = source, Scale = ToFloat(Get(data, "scale")), TargetPlayer = target });
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }


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


        private bool Guard(int player, string bucket)
        {
            if (player <= 0) return true;
            if (_limiter.TryConsume(player, "all", _eventRule)) return true;
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
            RecordGrant(player, kind, DateTime.UtcNow);
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

        private static string? LicenseOf(string handle)
        {
            var license = GetPlayerIdentifierByType(handle, "license");
            return string.IsNullOrEmpty(license) ? null : license;
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

        private static void Log(string message) => Debug.WriteLine("[jcks_anticheat] " + message);
    }
}
