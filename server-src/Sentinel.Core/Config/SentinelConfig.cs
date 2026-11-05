using System;
using System.Collections.Generic;
using System.Linq;
using Sentinel.Core.Detection;
using Sentinel.Core.Json;
using Sentinel.Core.Validation;

namespace Sentinel.Core.Config
{
    public sealed class VisionConfig
    {
        public bool Enabled { get; set; }
        /// <summary>"anthropic" or "openai-compatible" (DeepSeek and other OpenAI-style vision endpoints).</summary>
        public string Provider { get; set; } = "anthropic";
        public string Endpoint { get; set; } = "https://api.anthropic.com/v1/messages";
        public string Model { get; set; } = "claude-opus-5-5";
        /// <summary>Read from this environment variable, never from config.json.</summary>
        public string ApiKeyEnv { get; set; } = "SENTINEL_VISION_API_KEY";
        public string Effort { get; set; } = "medium";
        public double FlagConfidence { get; set; } = 0.8;
        public int MaxImageBytes { get; set; } = 3 * 1024 * 1024;
        public int CooldownSeconds { get; set; } = 120;
        /// <summary>Captures kept in resource/sentinel/data/vision; older files are deleted.</summary>
        public int MaxStoredCaptures { get; set; } = 500;
    }

    public sealed class DashboardConfig
    {
        public bool Enabled { get; set; }
        public string Url { get; set; } = "http://localhost:3000";
        /// <summary>Shared secret env var for the dashboard ingest API.</summary>
        public string SecretEnv { get; set; } = "SENTINEL_DASHBOARD_SECRET";
        public int FlushSeconds { get; set; } = 2;
        public int PollSeconds { get; set; } = 5;
        public string ServerId { get; set; } = "main";
    }

    public sealed class SentinelConfig
    {
        public ScoringPolicy Scoring { get; set; } = new ScoringPolicy();
        public MovementLimits Movement { get; set; } = new MovementLimits();
        public DamageLimits Damage { get; set; } = new DamageLimits();
        public ExplosionPolicy Explosions { get; set; } = new ExplosionPolicy();
        public EntityPolicy Entities { get; set; } = new EntityPolicy();
        public VisionConfig Vision { get; set; } = new VisionConfig();
        public DashboardConfig Dashboard { get; set; } = new DashboardConfig();

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

        /// <summary>Decoy net events. Real resources never fire these, so any trigger is a dumped-event replay.</summary>
        public List<string> HoneypotEvents { get; set; } = new List<string>
        {
            "esx:giveInventoryItem_admin", "bank:depositAll", "sentinel:adminGrant", "vrp:giveMoney", "qb-admin:server:setmoney",
        };

        /// <summary>Allowed per-player net events per second (burst capacity, refill/sec).</summary>
        public double EventBurst { get; set; } = 60;
        public double EventRefillPerSecond { get; set; } = 25;
        /// <summary>Rate-limited (denied) events within 10 s that turn NET_RATE into a NET_FLOOD disconnect.</summary>
        public int FloodDeniedPer10s { get; set; } = 40;

        public int HeartbeatIntervalMs { get; set; } = 5000;
        public int HeartbeatMissingSeconds { get; set; } = 20;
        /// <summary>Seconds a player may be in the world (has a ped) without completing the handshake.</summary>
        public int HandshakeTimeoutSeconds { get; set; } = 120;
        public int MaxHealth { get; set; } = 200;
        public double ExpectedDamageModifier { get; set; } = 1.0;
        public bool DryRun { get; set; }
        public List<string> AdminAce { get; set; } = new List<string> { "sentinel.bypass" };

        public static SentinelConfig Parse(string json)
        {
            var cfg = new SentinelConfig();
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
                    cfg.Entities.AllowedPedModels = new HashSet<uint>(peds.Select(Joaat.Hash));
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
