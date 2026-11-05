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
    /// <summary>
    /// Server authority. Wires FiveM events into the pure validators in JcksAnticheat.Core and enforces
    /// the verdicts. Idle cost: one coroutine that wakes once per second and returns at once when
    /// nobody is online; every other path is event-driven.
    /// </summary>
    public sealed partial class AnticheatScript : BaseScript
    {
        private readonly string _resource;
        private readonly AnticheatConfig _cfg;
        private readonly ViolationLedger _ledger;
        private readonly RateLimiter _limiter = new RateLimiter();
        private RateLimiter.Rule _eventRule; // rebuilt on settings reload
        private readonly RateLimiter.Rule _helloRule = new RateLimiter.Rule(3, 0.05);
        private readonly SlidingCounter _denied = new SlidingCounter();
        private readonly HeartbeatManager _heartbeats = new HeartbeatManager();
        private readonly MovementValidator _movement;
        private readonly DamageValidator _damage;
        private readonly AbsorbTracker _absorb = new AbsorbTracker();
        private readonly ExplosionValidator _explosions;
        private readonly GameEventValidator _gameEvents;
        private readonly VehicleOwnership _vehicles = new VehicleOwnership();
        private readonly EntityValidator _entities;
        private readonly PlayerStateValidator _state;
        private readonly StateConsistencyValidator _consistency = new StateConsistencyValidator();
        private readonly BanStore _bans;
        private readonly ScreenshotAssembler _screenshots = new ScreenshotAssembler();
        private readonly AIVisionEvaluator _vision;
        private readonly DashboardBridge _dashboard;
        private HashSet<uint> _weaponBlacklist; // rebuilt on settings reload
        private readonly string _dataDir;

        // Per-boot random event names. Only "jcks_anticheat:hello" and "jcks_anticheat:init" are fixed.
        private readonly string _hbEvent = HeartbeatManager.RandomEventName();
        private readonly string _ackEvent = HeartbeatManager.RandomEventName();
        private readonly string _graceEvent = HeartbeatManager.RandomEventName();
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
            _explosions = new ExplosionValidator(_cfg.Explosions);
            _entities = new EntityValidator(_cfg.Entities);
            _state = new PlayerStateValidator { MaxHealth = _cfg.MaxHealth };
            _weaponBlacklist = new HashSet<uint>(_cfg.WeaponBlacklist.Select(Joaat.Hash));
            _gameEvents = new GameEventValidator(_cfg.GameEvents, () => _weaponBlacklist);

            _dataDir = Path.Combine(GetResourcePath(_resource), "data");
            Directory.CreateDirectory(Path.Combine(_dataDir, "vision"));
            _bans = new BanStore(Path.Combine(_dataDir, "bans.json"));
            _vision = new AIVisionEvaluator(_cfg.Vision);
            _dashboard = new DashboardBridge(_cfg.Dashboard);

            RegisterEvents();
            // Players already connected when the resource (re)starts must handshake too.
            foreach (var p in Players) OnPlayerJoining(p, "");
            RegisterExports();
            RegisterSettings();
            Tick += OnTick;

            Log($"started: {_bans.All.Count} bans, vision={(_vision.IsConfigured ? _cfg.Vision.Provider + "/" + _cfg.Vision.Model : "off")}, " +
                $"dashboard={(_dashboard.Enabled ? _cfg.Dashboard.Url : "off")}, dryRun={_cfg.DryRun}");
        }

        private void RegisterEvents()
        {
            EventHandlers["playerConnecting"] += new Action<Player, string, CallbackDelegate, IDictionary<string, object>>(OnPlayerConnecting);
            EventHandlers["playerDropped"] += new Action<Player, string>(OnPlayerDropped);
            EventHandlers["playerJoining"] += new Action<Player, string>(OnPlayerJoining);
            EventHandlers["onServerResourceStart"] += new Action<string>(OnServerResourceStart);
            EventHandlers["jcks_anticheat:hello"] += new Action<Player>(OnHello);
            EventHandlers[_hbEvent] += new Action<Player, object, string, string, string>(OnHeartbeat);
            EventHandlers[_ssUploadEvent] += new Action<Player, string, int, int, string>(OnScreenshotChunk);

            RegisterHoneypots();
            RegisterProtectedEvents();

            // OneSync game events.
            EventHandlers["weaponDamageEvent"] += new Action<object, object>(OnWeaponDamage);
            EventHandlers["explosionEvent"] += new Action<object, object>(OnExplosion);
            EventHandlers["entityCreating"] += new Action<int>(OnEntityCreating);
            EventHandlers["entityCreated"] += new Action<int>(OnEntityCreated);
            EventHandlers["entityRemoved"] += new Action<int>(h => _vehicles.Untrack(NetworkGetNetworkIdFromEntity(h)));
            EventHandlers["giveWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "giveWeaponEvent"));
            EventHandlers["removeWeaponEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeWeaponEvent"));
            EventHandlers["removeAllWeaponsEvent"] += new Action<object, object>((s, d) => OnForbiddenWeaponEvent(s, "removeAllWeaponsEvent"));
            EventHandlers["clearPedTasksEvent"] += new Action<object, object>(OnClearPedTasks);
            EventHandlers["startProjectileEvent"] += new Action<object, object>(OnStartProjectile);
            EventHandlers["fireEvent"] += new Action<object, object>(OnFireEvent);
            EventHandlers["ptFxEvent"] += new Action<object, object>(OnPtfxEvent);
        }

        private void RegisterExports()
        {
            // exports.jcks_anticheat:GrantGrace(src, "heal" | "armor" | "teleport" | "godmode" | "invisible" | "noclip" | ..., ms)
            Exports.Add("GrantGrace", new Action<object, string, int>((src, kind, ms) => GrantGrace(ToId(src), kind, ms)));
            // exports.jcks_anticheat:Guard(src, "myresource:event") -> false when the player exceeds the event budget.
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
            var message = $"[JCKS Anticheat] You are banned. Reason: {ban.Reason} | Ban ID: {ban.Id} | Expires: {until}";
            ((CallbackDelegate)deferrals["defer"])();
            ((CallbackDelegate)deferrals["done"])(message);
            Log($"rejected banned connection {name} ({ban.Id})");
            _dashboard.Enqueue("connection_rejected", new Dictionary<string, object?> { ["name"] = name, ["banId"] = ban.Id });
        }

        /// <summary>
        /// A resource started after players joined (e.g. `ensure` from the console) is legitimate:
        /// tell every client before its own onClientResourceStart check flags it as injected.
        /// </summary>
        private void OnServerResourceStart(string name)
        {
            if (string.IsNullOrEmpty(name) || name == _resource) return;
            foreach (var p in Players)
                if (_heartbeats.HasSession(ToId(p.Handle))) p.TriggerEvent(_resourceEvent, name);
        }

        private void OnPlayerJoining([FromSource] Player player, string oldId)
        {
            int id = ToId(player.Handle);
            if (id <= 0) return;
            _ledger.Restore(id, LicenseOf(player.Handle));
            // Loading in and spawning teleports and heals the ped; server checks run from the start,
            // so they get the same grace the handshake grants.
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
            _consistency.Forget(id);
            _removing.TryRemove(id, out _);
            _ledger.Park(id, LicenseOf(player.Handle));
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
                ["sr"] = _ssRequestEvent, ["su"] = _ssUploadEvent, ["ru"] = _resourceEvent, ["iv"] = _cfg.HeartbeatIntervalMs,
                ["wb"] = _cfg.WeaponBlacklist, ["rs"] = StartedResources(), ["mh"] = _cfg.MaxHealth,
                ["dm"] = _cfg.ExpectedDamageModifier, ["ig"] = _cfg.Scoring.Ignore.ToList(),
                ["mw"] = _cfg.MaxWeapons, ["tb"] = _cfg.TextureBlacklist,
                ["se"] = _settingsEvent, ["po"] = _panelOpenEvent,
            };
            player.TriggerEvent("jcks_anticheat:init", MiniJson.Serialize(init));
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
            CheckReportedState(player, id, result.Payload.Obj("st"));

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

        /// <summary>Client-reported state (heartbeat "st") vs. what the server sees for the same ped.</summary>
        private void CheckReportedState(Player player, int id, Dictionary<string, object?>? st)
        {
            if (st == null || !(st.Arr("p") is List<object?> p) || p.Count < 3) return;
            int ped = GetPlayerPed(player.Handle);
            if (ped == 0) return;
            int serverHealth = GetEntityHealth(ped);
            var now = DateTime.UtcNow;
            int veh = GetVehiclePedIsIn(ped, false);
            var vel = GetEntityVelocity(veh != 0 ? veh : ped);
            // Teleports, heals and death legitimately make the two views diverge for a moment.
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

        /// <summary>
        /// Adds a listener to each protected server event (alongside the resource's own handler).
        /// Over the per-minute limit the trigger is reported and cancelled. CancelEvent stops handlers
        /// that check WasEventCanceled and later ones; it can't undo a handler that already ran.
        /// </summary>
        private void RegisterProtectedEvents()
        {
            foreach (var name in _cfg.ProtectedEvents.Keys)
            {
                if (!_protectedRegistered.Add(name)) continue;
                var eventName = name;
                EventHandlers[eventName] += new Action<Player>(p => OnProtectedEvent(p, eventName));
            }
        }

        private void OnProtectedEvent([FromSource] Player player, string eventName)
        {
            int id = ToId(player.Handle);
            if (id <= 0 || !_cfg.ProtectedEvents.TryGetValue(eventName, out var perMinute)) return;
            int n = _protectedCounter.Add(id + ":" + eventName, DateTime.UtcNow, TimeSpan.FromMinutes(1));
            if (n <= perMinute) return;
            CancelEvent();
            if (n == perMinute + 1 || n % 50 == 0)
                Punish(new Violation(id, "NET_EVENT_SPAM", ViolationSource.Server, new Dictionary<string, object?>
                {
                    ["event"] = eventName, ["perMinute"] = n, ["limit"] = perMinute,
                }));
        }

        /// <summary>Registers handlers for honeypot names not yet registered (also after a settings reload).</summary>
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
            // A name removed from the config in a live reload stays registered but goes quiet.
            if (!_cfg.HoneypotEvents.Contains(eventName)) return;
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
            bool scriptCreated = GetEntityPopulationType(handle) == 7; // POPTYPE_MISSION
            var (found, cancel) = _entities.Evaluate(owner, model, kind, scriptCreated, DateTime.UtcNow);
            foreach (var v in found) Punish(v);
            if (cancel) CancelEvent();
        }

        /// <summary>Remember who spawned each script-created vehicle (for VEH_HIJACK).</summary>
        private void OnEntityCreated(int handle)
        {
            if (GetEntityType(handle) != (int)EntityKind.Vehicle || GetEntityPopulationType(handle) != 7) return;
            int owner = NetworkGetEntityOwner(handle);
            if (owner > 0) _vehicles.Track(NetworkGetNetworkIdFromEntity(handle), owner);
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

        /// <summary>
        /// Player behind an explosion owner: the player whose ped it is, or the driver of a vehicle
        /// owner. 0 when there's no owner or it isn't tied to a player.
        /// </summary>
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

        /// <summary>Player who owns the entity with this net id, if it's a player's ped; else 0.</summary>
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
                // A projectile whose owner is someone else's ped is being fired "as" them.
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
