using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using JcksAnticheat.Core.Json;

namespace JcksAnticheat.Core.Config
{
    public sealed partial class AnticheatConfig
    {
        public Dictionary<string, object?> ToJson() => new Dictionary<string, object?>
        {
            ["dryRun"] = DryRun,
            ["heartbeatIntervalMs"] = HeartbeatIntervalMs,
            ["heartbeatMissingSeconds"] = HeartbeatMissingSeconds,
            ["handshakeTimeoutSeconds"] = HandshakeTimeoutSeconds,
            ["maxHealth"] = MaxHealth,
            ["expectedDamageModifier"] = ExpectedDamageModifier,
            ["eventBurst"] = EventBurst,
            ["eventRefillPerSecond"] = EventRefillPerSecond,
            ["floodDeniedPer10s"] = FloodDeniedPer10s,
            ["adminAce"] = AdminAce.ToList(),
            ["maxWeapons"] = MaxWeapons,
            ["textureBlacklist"] = TextureBlacklist.ToList(),
            ["server"] = ServerThresholds.OrderBy(k => k.Key, StringComparer.Ordinal).ToDictionary(k => k.Key, k => (object?)k.Value),
            ["client"] = ClientThresholds.OrderBy(k => k.Key, StringComparer.Ordinal).ToDictionary(k => k.Key, k => (object?)k.Value),
            ["blockHtmlNames"] = BlockHtmlNames,
            ["nameBlacklist"] = NameBlacklist.ToList(),
            ["chatSpoofCheck"] = ChatSpoofCheck,
            ["auditOnStart"] = AuditOnStart,
            ["protectedEvents"] = ProtectedEvents.OrderBy(k => k.Key, StringComparer.Ordinal).ToDictionary(k => k.Key, k => (object?)k.Value),
            ["scoring"] = new Dictionary<string, object?>
            {
                ["screenshotAt"] = Scoring.ScreenshotAt,
                ["kickAt"] = Scoring.KickAt,
                ["banAt"] = Scoring.BanAt,
                ["halfLifeMinutes"] = Scoring.HalfLifeMinutes,
                ["severity"] = Scoring.SeverityOverrides.OrderBy(k => k.Key, StringComparer.Ordinal)
                    .ToDictionary(k => k.Key, k => (object?)k.Value),
                ["ignore"] = Sorted(Scoring.Ignore),
                ["logOnly"] = Sorted(Scoring.LogOnly),
                ["dropImmediately"] = Sorted(Scoring.DropImmediately),
                ["alwaysBan"] = Sorted(Scoring.AlwaysBan),
            },
            ["movement"] = new Dictionary<string, object?>
            {
                ["onFootMaxSpeed"] = Movement.OnFootMaxSpeed, ["landMaxSpeed"] = Movement.LandMaxSpeed,
                ["airMaxSpeed"] = Movement.AirMaxSpeed, ["boatMaxSpeed"] = Movement.BoatMaxSpeed,
                ["teleportMinDistance"] = Movement.TeleportMinDistance, ["speedSlack"] = Movement.SpeedSlack,
            },
            ["damage"] = new Dictionary<string, object?>
            {
                ["bodyDamageMultiplier"] = Damage.BodyDamageMultiplier, ["headDamageMultiplier"] = Damage.HeadDamageMultiplier,
                ["rangeMultiplier"] = Damage.RangeMultiplier, ["maxAimAngle"] = Damage.MaxAimAngle,
                ["maxTrajectoryAngle"] = Damage.MaxTrajectoryAngle, ["headshotRatioMax"] = Damage.HeadshotRatioMax,
                ["aimAngleMinDistance"] = Damage.AimAngleMinDistance, ["rateMultiplier"] = Damage.RateMultiplier,
                ["headshotSampleSize"] = Damage.HeadshotSampleSize, ["headshotMinDistance"] = Damage.HeadshotMinDistance,
            },
            ["explosions"] = new Dictionary<string, object?>
            {
                ["blacklist"] = Explosions.Blacklist.OrderBy(x => x).Cast<object?>().ToList(),
                ["maxPerSecond"] = Explosions.MaxPerSecond, ["maxPer10Seconds"] = Explosions.MaxPer10Seconds,
            },
            ["entities"] = new Dictionary<string, object?>
            {
                ["maxVehiclesPer10s"] = Entities.MaxVehiclesPer10s, ["maxEntitiesPer10s"] = Entities.MaxEntitiesPer10s, ["maxAttachedToOthers"] = Entities.MaxAttachedToOthers, ["blockUnknownScript"] = Entities.BlockUnknownScript,
                ["allowedPedModels"] = Entities.AllowedPedModelNames.ToList(),
            },
            ["gameEvents"] = new Dictionary<string, object?>
            {
                ["projectileOriginMaxDistance"] = GameEvents.ProjectileOriginMaxDistance, ["maxProjectilesPer10s"] = GameEvents.MaxProjectilesPer10s,
                ["maxFiresPer10s"] = GameEvents.MaxFiresPer10s, ["maxPtfxPer10s"] = GameEvents.MaxPtfxPer10s, ["maxPtfxScale"] = GameEvents.MaxPtfxScale,
            },
            ["weaponBlacklist"] = WeaponBlacklist.ToList(),
            ["vehicleBlacklist"] = VehicleBlacklist.ToList(),
            ["objectBlacklist"] = ObjectBlacklist.ToList(),
            ["honeypotEvents"] = HoneypotEvents.ToList(),
            ["vision"] = new Dictionary<string, object?>
            {
                ["enabled"] = Vision.Enabled, ["provider"] = Vision.Provider, ["endpoint"] = Vision.Endpoint,
                ["model"] = Vision.Model, ["apiKeyEnv"] = Vision.ApiKeyEnv, ["effort"] = Vision.Effort,
                ["flagConfidence"] = Vision.FlagConfidence, ["cooldownSeconds"] = Vision.CooldownSeconds,
                ["maxStoredCaptures"] = Vision.MaxStoredCaptures,
            },
            ["antiDump"] = new Dictionary<string, object?>
            {
                ["enabled"] = AntiDump.Enabled,
                ["resources"] = AntiDump.Resources.OrderBy(k => k.Key, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(k => k.Key, k => (object?)k.Value.Cast<object?>().ToList()),
            },
            ["countermeasures"] = new Dictionary<string, object?>
            {
                ["enabled"] = Countermeasures.Enabled, ["skip"] = Countermeasures.Skip.ToList(),
            },
            ["integrations"] = new Dictionary<string, object?>
            {
                ["usePresets"] = Integrations.UsePresets, ["learning"] = Integrations.Learning, ["graceMs"] = Integrations.GraceMs,
                ["clientTrustAllResources"] = Integrations.ClientTrustAllResources,
                ["serverTrustReportedResources"] = Integrations.ServerTrustReportedResources,
                ["resources"] = Integrations.Resources.OrderBy(k => k.Key, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(k => k.Key, k => (object?)k.Value.Cast<object?>().ToList()),
            },
            ["backdoorScanner"] = new Dictionary<string, object?>
            {
                ["enabled"] = Backdoor.Enabled, ["scanOnStart"] = Backdoor.ScanOnStart, ["minSeverity"] = Backdoor.MinSeverity,
                ["autoAction"] = Backdoor.AutoAction, ["autoActionMinSeverity"] = Backdoor.AutoActionMinSeverity,
                ["ignoreIds"] = Backdoor.IgnoreIds.ToList(), ["ignoreResources"] = Backdoor.IgnoreResources.ToList(),
                ["disabledRules"] = Backdoor.DisabledRules.ToList(),
            },
            ["discord"] = new Dictionary<string, object?>
            {
                ["enabled"] = Discord.Enabled, ["webhookEnv"] = Discord.WebhookEnv, ["minAction"] = Discord.MinAction, ["username"] = Discord.Username,
            },
            ["dashboard"] = new Dictionary<string, object?>
            {
                ["enabled"] = Dashboard.Enabled, ["url"] = Dashboard.Url, ["secretEnv"] = Dashboard.SecretEnv, ["serverId"] = Dashboard.ServerId,
            },
        };

        public string ToPrettyJson() => Pretty(MiniJson.Serialize(ToJson()));

        public void CopyFrom(AnticheatConfig other) => CopyInto(this, other);

        private static void CopyInto(object target, object source)
        {
            foreach (var prop in target.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (!prop.CanRead || !prop.CanWrite || prop.GetIndexParameters().Length > 0) continue;
                var value = prop.GetValue(source);
                var type = prop.PropertyType;
                bool nestedPolicy = type.IsClass && type != typeof(string) && !typeof(IEnumerable).IsAssignableFrom(type)
                                    && type.Namespace != null && type.Namespace.StartsWith("JcksAnticheat", StringComparison.Ordinal);
                if (nestedPolicy && value != null && prop.GetValue(target) is { } existing) CopyInto(existing, value);
                else prop.SetValue(target, value);
            }
        }

        public List<string> Validate()
        {
            var errors = new List<string>();
            void Require(bool ok, string message) { if (!ok) errors.Add(message); }

            Require(Scoring.ScreenshotAt > 0 && Scoring.KickAt > 0 && Scoring.BanAt > 0, "scoring thresholds must be positive");
            Require(Scoring.ScreenshotAt <= Scoring.KickAt, "scoring.screenshotAt must not exceed scoring.kickAt");
            Require(Scoring.KickAt < Scoring.BanAt, "scoring.kickAt must be below scoring.banAt");
            Require(Scoring.HalfLifeMinutes > 0, "scoring.halfLifeMinutes must be positive");
            Require(HeartbeatIntervalMs >= 1000 && HeartbeatIntervalMs <= 30000, "heartbeatIntervalMs must be 1000–30000");
            Require(HeartbeatMissingSeconds * 1000 > HeartbeatIntervalMs * 2, "heartbeatMissingSeconds must cover at least two heartbeat intervals");
            Require(HandshakeTimeoutSeconds >= 30, "handshakeTimeoutSeconds must be at least 30");
            Require(MaxHealth >= 100 && MaxHealth <= 10000, "maxHealth must be 100–10000");
            Require(EventBurst >= 5 && EventRefillPerSecond >= 1, "eventBurst ≥ 5 and eventRefillPerSecond ≥ 1");
            Require(FloodDeniedPer10s >= 5, "floodDeniedPer10s must be at least 5");
            Require(Movement.OnFootMaxSpeed > 0 && Movement.LandMaxSpeed > 0 && Movement.AirMaxSpeed > 0 && Movement.BoatMaxSpeed > 0, "movement speeds must be positive");
            Require(Movement.SpeedSlack >= 1, "movement.speedSlack must be at least 1");
            Require(Damage.BodyDamageMultiplier >= 1 && Damage.HeadDamageMultiplier >= 1 && Damage.RangeMultiplier >= 1, "damage multipliers must be at least 1");
            Require(Damage.MaxAimAngle > 0 && Damage.MaxAimAngle <= 180 && Damage.MaxTrajectoryAngle > 0 && Damage.MaxTrajectoryAngle <= 90, "damage angles out of range");
            Require(Damage.HeadshotRatioMax > 0 && Damage.HeadshotRatioMax <= 1, "damage.headshotRatioMax must be 0–1");
            Require(Explosions.MaxPerSecond >= 1 && Explosions.MaxPer10Seconds >= Explosions.MaxPerSecond, "explosion limits invalid");
            Require(Entities.MaxVehiclesPer10s >= 1 && Entities.MaxEntitiesPer10s >= Entities.MaxVehiclesPer10s, "entity limits invalid");
            Require(Entities.MaxAttachedToOthers >= 1 && Entities.MaxAttachedToOthers <= 100, "entities.maxAttachedToOthers must be 1–100");
            Require(GameEvents.ProjectileOriginMaxDistance >= 2 && GameEvents.MaxProjectilesPer10s >= 1 && GameEvents.MaxFiresPer10s >= 1
                    && GameEvents.MaxPtfxPer10s >= 1 && GameEvents.MaxPtfxScale > 0, "gameEvents limits invalid");
            Require(Vision.Provider == "anthropic" || Vision.Provider == "openai-compatible", "vision.provider must be anthropic or openai-compatible");
            Require(Vision.FlagConfidence >= 0 && Vision.FlagConfidence <= 1, "vision.flagConfidence must be 0–1");
            Require(Uri.TryCreate(Vision.Endpoint, UriKind.Absolute, out _), "vision.endpoint must be an absolute URL");
            Require(Uri.TryCreate(Dashboard.Url, UriKind.Absolute, out _), "dashboard.url must be an absolute URL");
            Require(!string.IsNullOrWhiteSpace(Dashboard.ServerId), "dashboard.serverId is required");
            foreach (var kv in Scoring.SeverityOverrides)
                Require(kv.Value >= 0 && kv.Value <= 1000 && System.Text.RegularExpressions.Regex.IsMatch(kv.Key, "^[A-Z_]{3,48}$"),
                    "scoring.severity entry " + kv.Key + " must be CODE=0..1000");
            foreach (var kv in ProtectedEvents)
                Require(kv.Value >= 1 && kv.Value <= 10000 && kv.Key.Length > 0 && kv.Key.Length <= 128,
                    "protectedEvents entry " + kv.Key + " must be event=1..10000");
            foreach (var kv in AntiDump.Resources)
                Require(kv.Value.All(JcksAnticheat.Core.AntiDump.AntiDumpManifest.SafePath), "antiDump.resources." + kv.Key + ": files must be .lua paths inside the resource");
            Require(Integrations.GraceMs >= 500 && Integrations.GraceMs <= 120000, "integrations.graceMs must be 500–120000");
            foreach (var kv in Integrations.Resources)
                Require(kv.Value.All(Behaviours.IsKnown), "integrations.resources." + kv.Key + ": unknown behaviour (allowed: " + string.Join(", ", Behaviours.All) + ", *)");
            Require(new[] { "low", "medium", "high" }.Contains(Backdoor.MinSeverity) && new[] { "low", "medium", "high" }.Contains(Backdoor.AutoActionMinSeverity),
                "backdoorScanner severities must be low, medium or high");
            Require(new[] { "none", "remove", "quarantine" }.Contains(Backdoor.AutoAction), "backdoorScanner.autoAction must be none, remove or quarantine");
            Require(new[] { "log", "screenshot", "kick", "ban" }.Contains(Discord.MinAction), "discord.minAction must be log, screenshot, kick or ban");
            foreach (var kv in ServerThresholds)
                Require(kv.Value > 0 && kv.Value < 100000, "server." + kv.Key + " must be positive");
            Require(Damage.RateMultiplier >= 1 && Damage.HeadshotSampleSize >= 5 && Damage.AimAngleMinDistance >= 0 && Damage.HeadshotMinDistance >= 0, "damage sampling settings invalid");
            foreach (var kv in ClientThresholds)
                Require(kv.Value > 0 && kv.Value < 100000, "client." + kv.Key + " must be positive");
            Require(MaxWeapons >= 5 && MaxWeapons <= 200, "maxWeapons must be 5–200");
            Require(AdminAce.Count > 0, "adminAce needs at least one entry");
            return errors;
        }

        public static AnticheatConfig ParseValidated(string json)
        {
            var cfg = Parse(json);
            var errors = cfg.Validate();
            if (errors.Count > 0) throw new FormatException(string.Join("; ", errors));
            return cfg;
        }

        private static List<object?> Sorted(IEnumerable<string> items) => items.OrderBy(x => x, StringComparer.Ordinal).Cast<object?>().ToList();

        private static string Pretty(string json)
        {
            var sb = new StringBuilder(json.Length * 2);
            int indent = 0;
            bool inString = false;
            for (int i = 0; i < json.Length; i++)
            {
                char c = json[i];
                if (inString)
                {
                    sb.Append(c);
                    if (c == '\\' && i + 1 < json.Length) sb.Append(json[++i]);
                    else if (c == '"') inString = false;
                    continue;
                }
                switch (c)
                {
                    case '"': inString = true; sb.Append(c); break;
                    case '{':
                    case '[':
                        char close = c == '{' ? '}' : ']';
                        if (i + 1 < json.Length && json[i + 1] == close) { sb.Append(c).Append(close); i++; break; }
                        sb.Append(c).Append('\n').Append(' ', ++indent * 2);
                        break;
                    case '}':
                    case ']': sb.Append('\n').Append(' ', --indent * 2).Append(c); break;
                    case ',': sb.Append(",\n").Append(' ', indent * 2); break;
                    case ':': sb.Append(": "); break;
                    default: sb.Append(c); break;
                }
            }
            return sb.Append('\n').ToString();
        }
    }
}
