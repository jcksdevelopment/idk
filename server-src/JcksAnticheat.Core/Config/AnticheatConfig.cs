using System;
using System.Collections.Generic;
using System.Linq;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Validation;

namespace JcksAnticheat.Core.Config
{
    public sealed class VisionConfig
    {
        public bool Enabled { get; set; }
        public string Provider { get; set; } = "anthropic";
        public string Endpoint { get; set; } = "https://api.anthropic.com/v1/messages";
        public string Model { get; set; } = "claude-opus-5-5";
        public string ApiKeyEnv { get; set; } = "JCKS_AC_VISION_API_KEY";
        public string Effort { get; set; } = "medium";
        public double FlagConfidence { get; set; } = 0.8;
        public int MaxImageBytes { get; set; } = 3 * 1024 * 1024;
        public int CooldownSeconds { get; set; } = 120;
        public int MaxStoredCaptures { get; set; } = 500;
    }

    public sealed class DashboardConfig
    {
        public bool Enabled { get; set; }
        public string Url { get; set; } = "http://localhost:3000";
        public string SecretEnv { get; set; } = "JCKS_AC_DASHBOARD_SECRET";
        public int FlushSeconds { get; set; } = 2;
        public int PollSeconds { get; set; } = 5;
        public string ServerId { get; set; } = "main";
    }

    public sealed class AntiDumpConfig
    {
        public bool Enabled { get; set; }
        public Dictionary<string, List<string>> Resources { get; set; } = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
    }

    public sealed class CountermeasuresConfig
    {
        public bool Enabled { get; set; } = true;
        public List<string> Skip { get; set; } = new List<string>();
    }

    public sealed class BackdoorConfig
    {
        public bool Enabled { get; set; } = true;
        public bool ScanOnStart { get; set; } = true;
        public string MinSeverity { get; set; } = "medium";
        public string AutoAction { get; set; } = "none";
        public string AutoActionMinSeverity { get; set; } = "high";
        public List<string> IgnoreIds { get; set; } = new List<string>();
        public List<string> IgnoreResources { get; set; } = new List<string>();
        public List<string> DisabledRules { get; set; } = new List<string>();
    }

    public sealed partial class AnticheatConfig
    {
        public ScoringPolicy Scoring { get; set; } = new ScoringPolicy();
        public MovementLimits Movement { get; set; } = new MovementLimits();
        public DamageLimits Damage { get; set; } = new DamageLimits();
        public ExplosionPolicy Explosions { get; set; } = new ExplosionPolicy();
        public EntityPolicy Entities { get; set; } = new EntityPolicy();
        public GameEventPolicy GameEvents { get; set; } = new GameEventPolicy();
        public VisionConfig Vision { get; set; } = new VisionConfig();
        public DashboardConfig Dashboard { get; set; } = new DashboardConfig();
        public BackdoorConfig Backdoor { get; set; } = new BackdoorConfig();
        public CountermeasuresConfig Countermeasures { get; set; } = new CountermeasuresConfig();
        public AntiDumpConfig AntiDump { get; set; } = new AntiDumpConfig();
        public IntegrationsConfig Integrations { get; set; } = new IntegrationsConfig();
        public JcksAnticheat.Core.Logging.DiscordConfig Discord { get; set; } = new JcksAnticheat.Core.Logging.DiscordConfig();

        public List<string> WeaponBlacklist { get; set; } = new List<string>
        {
            "WEAPON_RAILGUN", "WEAPON_RAILGUNXM3", "WEAPON_MINIGUN", "WEAPON_RPG", "WEAPON_HOMINGLAUNCHER",
            "WEAPON_GRENADELAUNCHER", "WEAPON_COMPACTLAUNCHER", "WEAPON_STICKYBOMB", "WEAPON_PROXMINE",
            "WEAPON_RAYPISTOL", "WEAPON_RAYCARBINE", "WEAPON_RAYMINIGUN", "WEAPON_EMPLAUNCHER", "WEAPON_FIREWORK",
        };

        public List<string> VehicleBlacklist { get; set; } = new List<string>
        {
            "rhino", "khanjali", "hydra", "lazer", "oppressor", "oppressor2", "jet", "cargoplane", "blimp", "blimp2",
            "blimp3", "titan", "volatol", "avenger", "deluxo", "scramjet", "vigilante", "ruiner2", "apc", "chernobog",
        };

        public List<string> ObjectBlacklist { get; set; } = new List<string>
        {
            "prop_beach_fire", "prop_windmill_01", "stt_prop_stunt_track_start", "prop_gold_cont_01",
            "p_spinning_anus_s", "prop_fnclink_05crnr1", "xs_prop_hamburgher_wl", "prop_container_01a",
        };

        public List<string> HoneypotEvents { get; set; } = new List<string>
        {
            "esx:giveInventoryItem_admin", "bank:depositAll", "jcks_anticheat:adminGrant", "vrp:giveMoney", "qb-admin:server:setmoney",
        };

        public double EventBurst { get; set; } = 60;
        public double EventRefillPerSecond { get; set; } = 25;
        public int FloodDeniedPer10s { get; set; } = 40;

        public int HeartbeatIntervalMs { get; set; } = 5000;
        public int HeartbeatMissingSeconds { get; set; } = 20;
        public int HandshakeTimeoutSeconds { get; set; } = 120;
        public int MaxHealth { get; set; } = 200;
        public double ExpectedDamageModifier { get; set; } = 1.0;
        public bool DryRun { get; set; }
        public int MaxWeapons { get; set; } = 25;
        public List<string> TextureBlacklist { get; set; } = new List<string>();
        public bool BlockHtmlNames { get; set; } = true;
        public List<string> NameBlacklist { get; set; } = new List<string>();
        public bool ChatSpoofCheck { get; set; } = true;
        public Dictionary<string, int> ProtectedEvents { get; set; } = new Dictionary<string, int>(StringComparer.Ordinal);
        public List<string> AdminAce { get; set; } = new List<string> { "jcks_anticheat.bypass" };

        public static AnticheatConfig Parse(string json)
        {
            var cfg = new AnticheatConfig();
            var root = MiniJson.Parse(json) as Dictionary<string, object?>;
            if (root == null) return cfg;

            cfg.DryRun = root.Bool("dryRun") ?? cfg.DryRun;
            cfg.HeartbeatIntervalMs = (int)(root.Num("heartbeatIntervalMs") ?? cfg.HeartbeatIntervalMs);
            cfg.HeartbeatMissingSeconds = (int)(root.Num("heartbeatMissingSeconds") ?? cfg.HeartbeatMissingSeconds);
            cfg.HandshakeTimeoutSeconds = (int)(root.Num("handshakeTimeoutSeconds") ?? cfg.HandshakeTimeoutSeconds);
            cfg.MaxHealth = (int)(root.Num("maxHealth") ?? cfg.MaxHealth);
            cfg.ExpectedDamageModifier = root.Num("expectedDamageModifier") ?? cfg.ExpectedDamageModifier;
            cfg.EventBurst = root.Num("eventBurst") ?? cfg.EventBurst;
            cfg.EventRefillPerSecond = root.Num("eventRefillPerSecond") ?? cfg.EventRefillPerSecond;
            cfg.FloodDeniedPer10s = (int)(root.Num("floodDeniedPer10s") ?? cfg.FloodDeniedPer10s);
            cfg.WeaponBlacklist = Strings(root, "weaponBlacklist") ?? cfg.WeaponBlacklist;
            cfg.VehicleBlacklist = Strings(root, "vehicleBlacklist") ?? cfg.VehicleBlacklist;
            cfg.ObjectBlacklist = Strings(root, "objectBlacklist") ?? cfg.ObjectBlacklist;
            cfg.HoneypotEvents = Strings(root, "honeypotEvents") ?? cfg.HoneypotEvents;
            cfg.AdminAce = Strings(root, "adminAce") ?? cfg.AdminAce;
            cfg.MaxWeapons = (int)(root.Num("maxWeapons") ?? cfg.MaxWeapons);
            cfg.TextureBlacklist = Strings(root, "textureBlacklist") ?? cfg.TextureBlacklist;
            cfg.BlockHtmlNames = root.Bool("blockHtmlNames") ?? cfg.BlockHtmlNames;
            cfg.NameBlacklist = Strings(root, "nameBlacklist") ?? cfg.NameBlacklist;
            cfg.ChatSpoofCheck = root.Bool("chatSpoofCheck") ?? cfg.ChatSpoofCheck;
            if (root.Obj("protectedEvents") is { } pe)
            {
                cfg.ProtectedEvents = new Dictionary<string, int>(StringComparer.Ordinal);
                foreach (var kv in pe) if (kv.Value is double d) cfg.ProtectedEvents[kv.Key] = (int)d;
            }

            if (root.Obj("scoring") is { } s)
            {
                cfg.Scoring.ScreenshotAt = s.Num("screenshotAt") ?? cfg.Scoring.ScreenshotAt;
                cfg.Scoring.KickAt = s.Num("kickAt") ?? cfg.Scoring.KickAt;
                cfg.Scoring.BanAt = s.Num("banAt") ?? cfg.Scoring.BanAt;
                cfg.Scoring.HalfLifeMinutes = s.Num("halfLifeMinutes") ?? cfg.Scoring.HalfLifeMinutes;
                if (s.Obj("severity") is { } sev)
                    foreach (var kv in sev) if (kv.Value is double d) cfg.Scoring.SeverityOverrides[kv.Key] = (int)d;
                if (Strings(s, "logOnly") is { } lo) cfg.Scoring.LogOnly = new HashSet<string>(lo, StringComparer.Ordinal);
                if (Strings(s, "ignore") is { } ig) cfg.Scoring.Ignore = new HashSet<string>(ig, StringComparer.Ordinal);
                if (Strings(s, "alwaysBan") is { } ab) cfg.Scoring.AlwaysBan = new HashSet<string>(ab, StringComparer.Ordinal);
                if (Strings(s, "dropImmediately") is { } di) cfg.Scoring.DropImmediately = new HashSet<string>(di, StringComparer.Ordinal);
            }

            if (root.Obj("movement") is { } m)
            {
                cfg.Movement.OnFootMaxSpeed = (float)(m.Num("onFootMaxSpeed") ?? cfg.Movement.OnFootMaxSpeed);
                cfg.Movement.LandMaxSpeed = (float)(m.Num("landMaxSpeed") ?? cfg.Movement.LandMaxSpeed);
                cfg.Movement.AirMaxSpeed = (float)(m.Num("airMaxSpeed") ?? cfg.Movement.AirMaxSpeed);
                cfg.Movement.BoatMaxSpeed = (float)(m.Num("boatMaxSpeed") ?? cfg.Movement.BoatMaxSpeed);
                cfg.Movement.TeleportMinDistance = (float)(m.Num("teleportMinDistance") ?? cfg.Movement.TeleportMinDistance);
                cfg.Movement.SpeedSlack = (float)(m.Num("speedSlack") ?? cfg.Movement.SpeedSlack);
            }

            if (root.Obj("damage") is { } dmg)
            {
                cfg.Damage.BodyDamageMultiplier = (float)(dmg.Num("bodyDamageMultiplier") ?? cfg.Damage.BodyDamageMultiplier);
                cfg.Damage.HeadDamageMultiplier = (float)(dmg.Num("headDamageMultiplier") ?? cfg.Damage.HeadDamageMultiplier);
                cfg.Damage.RangeMultiplier = (float)(dmg.Num("rangeMultiplier") ?? cfg.Damage.RangeMultiplier);
                cfg.Damage.MaxAimAngle = (float)(dmg.Num("maxAimAngle") ?? cfg.Damage.MaxAimAngle);
                cfg.Damage.MaxTrajectoryAngle = (float)(dmg.Num("maxTrajectoryAngle") ?? cfg.Damage.MaxTrajectoryAngle);
                cfg.Damage.HeadshotRatioMax = dmg.Num("headshotRatioMax") ?? cfg.Damage.HeadshotRatioMax;
            }

            if (root.Obj("explosions") is { } ex)
            {
                if (ex.Arr("blacklist") is { } bl) cfg.Explosions.Blacklist = new HashSet<int>(bl.OfType<double>().Select(x => (int)x));
                cfg.Explosions.MaxPerSecond = (int)(ex.Num("maxPerSecond") ?? cfg.Explosions.MaxPerSecond);
                cfg.Explosions.MaxPer10Seconds = (int)(ex.Num("maxPer10Seconds") ?? cfg.Explosions.MaxPer10Seconds);
            }

            if (root.Obj("entities") is { } en)
            {
                cfg.Entities.MaxVehiclesPer10s = (int)(en.Num("maxVehiclesPer10s") ?? cfg.Entities.MaxVehiclesPer10s);
                cfg.Entities.MaxEntitiesPer10s = (int)(en.Num("maxEntitiesPer10s") ?? cfg.Entities.MaxEntitiesPer10s);
                if (Strings(en, "allowedPedModels") is { } peds)
                {
                    cfg.Entities.AllowedPedModelNames = peds;
                    cfg.Entities.AllowedPedModels = new HashSet<uint>(peds.Select(Joaat.Hash));
                }
            }

            if (root.Obj("gameEvents") is { } ge)
            {
                cfg.GameEvents.ProjectileOriginMaxDistance = (float)(ge.Num("projectileOriginMaxDistance") ?? cfg.GameEvents.ProjectileOriginMaxDistance);
                cfg.GameEvents.MaxProjectilesPer10s = (int)(ge.Num("maxProjectilesPer10s") ?? cfg.GameEvents.MaxProjectilesPer10s);
                cfg.GameEvents.MaxFiresPer10s = (int)(ge.Num("maxFiresPer10s") ?? cfg.GameEvents.MaxFiresPer10s);
                cfg.GameEvents.MaxPtfxPer10s = (int)(ge.Num("maxPtfxPer10s") ?? cfg.GameEvents.MaxPtfxPer10s);
                cfg.GameEvents.MaxPtfxScale = (float)(ge.Num("maxPtfxScale") ?? cfg.GameEvents.MaxPtfxScale);
            }

            if (root.Obj("vision") is { } v)
            {
                cfg.Vision.Enabled = v.Bool("enabled") ?? cfg.Vision.Enabled;
                cfg.Vision.Provider = v.Str("provider") ?? cfg.Vision.Provider;
                cfg.Vision.Endpoint = v.Str("endpoint") ?? cfg.Vision.Endpoint;
                cfg.Vision.Model = v.Str("model") ?? cfg.Vision.Model;
                cfg.Vision.ApiKeyEnv = v.Str("apiKeyEnv") ?? cfg.Vision.ApiKeyEnv;
                cfg.Vision.Effort = v.Str("effort") ?? cfg.Vision.Effort;
                cfg.Vision.FlagConfidence = v.Num("flagConfidence") ?? cfg.Vision.FlagConfidence;
                cfg.Vision.CooldownSeconds = (int)(v.Num("cooldownSeconds") ?? cfg.Vision.CooldownSeconds);
                cfg.Vision.MaxStoredCaptures = (int)(v.Num("maxStoredCaptures") ?? cfg.Vision.MaxStoredCaptures);
            }

            if (root.Obj("antiDump") is { } ado)
            {
                cfg.AntiDump.Enabled = ado.Bool("enabled") ?? cfg.AntiDump.Enabled;
                if (ado.Obj("resources") is { } adr)
                {
                    cfg.AntiDump.Resources = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
                    foreach (var kv in adr)
                        if (kv.Value is List<object?> list) cfg.AntiDump.Resources[kv.Key] = list.OfType<string>().ToList();
                }
            }

            if (root.Obj("countermeasures") is { } cmo)
            {
                cfg.Countermeasures.Enabled = cmo.Bool("enabled") ?? cfg.Countermeasures.Enabled;
                cfg.Countermeasures.Skip = Strings(cmo, "skip") ?? cfg.Countermeasures.Skip;
            }

            if (root.Obj("integrations") is { } igr)
            {
                cfg.Integrations.UsePresets = igr.Bool("usePresets") ?? cfg.Integrations.UsePresets;
                cfg.Integrations.Learning = igr.Bool("learning") ?? cfg.Integrations.Learning;
                cfg.Integrations.ClientTrustAllResources = igr.Bool("clientTrustAllResources") ?? cfg.Integrations.ClientTrustAllResources;
                cfg.Integrations.ServerTrustReportedResources = igr.Bool("serverTrustReportedResources") ?? cfg.Integrations.ServerTrustReportedResources;
                cfg.Integrations.GraceMs = (int)(igr.Num("graceMs") ?? cfg.Integrations.GraceMs);
                if (igr.Obj("resources") is { } rs)
                {
                    cfg.Integrations.Resources = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
                    foreach (var kv in rs)
                        if (kv.Value is List<object?> list) cfg.Integrations.Resources[kv.Key] = list.OfType<string>().ToList();
                }
            }

            if (root.Obj("backdoorScanner") is { } bd)
            {
                cfg.Backdoor.Enabled = bd.Bool("enabled") ?? cfg.Backdoor.Enabled;
                cfg.Backdoor.ScanOnStart = bd.Bool("scanOnStart") ?? cfg.Backdoor.ScanOnStart;
                cfg.Backdoor.MinSeverity = bd.Str("minSeverity") ?? cfg.Backdoor.MinSeverity;
                cfg.Backdoor.AutoAction = bd.Str("autoAction") ?? cfg.Backdoor.AutoAction;
                cfg.Backdoor.AutoActionMinSeverity = bd.Str("autoActionMinSeverity") ?? cfg.Backdoor.AutoActionMinSeverity;
                cfg.Backdoor.IgnoreIds = Strings(bd, "ignoreIds") ?? cfg.Backdoor.IgnoreIds;
                cfg.Backdoor.IgnoreResources = Strings(bd, "ignoreResources") ?? cfg.Backdoor.IgnoreResources;
                cfg.Backdoor.DisabledRules = Strings(bd, "disabledRules") ?? cfg.Backdoor.DisabledRules;
            }

            if (root.Obj("discord") is { } dc)
            {
                cfg.Discord.Enabled = dc.Bool("enabled") ?? cfg.Discord.Enabled;
                cfg.Discord.WebhookEnv = dc.Str("webhookEnv") ?? cfg.Discord.WebhookEnv;
                cfg.Discord.MinAction = dc.Str("minAction") ?? cfg.Discord.MinAction;
                cfg.Discord.Username = dc.Str("username") ?? cfg.Discord.Username;
            }

            if (root.Obj("dashboard") is { } db)
            {
                cfg.Dashboard.Enabled = db.Bool("enabled") ?? cfg.Dashboard.Enabled;
                cfg.Dashboard.Url = (db.Str("url") ?? cfg.Dashboard.Url).TrimEnd('/');
                cfg.Dashboard.SecretEnv = db.Str("secretEnv") ?? cfg.Dashboard.SecretEnv;
                cfg.Dashboard.ServerId = db.Str("serverId") ?? cfg.Dashboard.ServerId;
            }

            cfg.Entities.BlacklistedModels = new HashSet<uint>(cfg.VehicleBlacklist.Concat(cfg.ObjectBlacklist).Select(Joaat.Hash));
            return cfg;
        }

        private static List<string>? Strings(Dictionary<string, object?> o, string key)
            => o.Arr(key)?.OfType<string>().ToList();
    }
}
