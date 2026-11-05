using System;
using System.Collections.Generic;

namespace JcksAnticheat.Core.Audit
{
    public sealed class AuditFinding
    {
        public AuditFinding(string severity, string convar, string current, string recommended, string why)
        {
            Severity = severity; Convar = convar; Current = current; Recommended = recommended; Why = why;
        }
        public string Severity { get; }
        public string Convar { get; }
        public string Current { get; }
        public string Recommended { get; }
        public string Why { get; }
        public override string ToString() => $"[{Severity.ToUpperInvariant()}] {Convar} = '{Current}' -> set {Convar} {Recommended}: {Why}";
    }

    public static class ServerAudit
    {
        private static readonly (string name, double rate, double burst)[] DefaultLimiters =
        {
            ("netEvent", 50, 200), ("netEventFlood", 75, 300), ("stateBag", 75, 125), ("stateBagFlood", 150, 175),
            ("netCommand", 7, 14), ("netCommandFlood", 25, 45),
        };

        public static int? ArtifactBuild(string? version)
        {
            if (string.IsNullOrEmpty(version)) return null;
            var m = System.Text.RegularExpressions.Regex.Match(version, @"v1\.0\.0\.(\d+)");
            return m.Success && int.TryParse(m.Groups[1].Value, out var b) ? b : (int?)null;
        }

        private static bool Truthy(string v) => v == "true" || v == "1" || v == "on" || v == "yes";

        public static List<AuditFinding> Evaluate(Func<string, string, string> convar)
        {
            var found = new List<AuditFinding>();
            string Get(string name, string fallback) => (convar(name, fallback) ?? fallback).Trim().ToLowerInvariant();

            var onesync = Get("onesync", "off");
            if (onesync != "on")
                found.Add(new AuditFinding("high", "onesync", onesync, "on",
                    "Server-side checks (movement, health, entities, game events, sync flags) read OneSync state and do nothing without it."));

            if (Truthy(Get("sv_scriptHookAllowed", "false")))
                found.Add(new AuditFinding("high", "sv_scriptHookAllowed", "true", "false",
                    "Lets clients with Script Hook V join; the FiveM docs mark this as not recommended."));

            if (Truthy(Get("sv_enableNetworkedPhoneExplosions", "false")))
                found.Add(new AuditFinding("high", "sv_enableNetworkedPhoneExplosions", "true", "false",
                    "Routes REQUEST_PHONE_EXPLOSION_EVENT, which the docs say malicious actors use."));

            var filter = Get("sv_filterRequestControl", "0");
            if (filter == "0" || filter == "")
                found.Add(new AuditFinding("medium", "sv_filterRequestControl", filter == "" ? "0" : filter, "2",
                    "Stops players taking control of entities other players control (vehicle hijack/delete menus). Mode 1 is gentler if a script needs control requests."));

            if (Truthy(Get("sv_enableNetworkedSounds", "true")))
                found.Add(new AuditFinding("medium", "sv_enableNetworkedSounds", "true", "false",
                    "NETWORK_PLAY_SOUND_EVENT is commonly abused for sound spam; turn it off unless a script plays networked sounds."));

            if (Truthy(Get("sv_enableNetworkedScriptEntityStates", "true")))
                found.Add(new AuditFinding("low", "sv_enableNetworkedScriptEntityStates", "true", "false",
                    "SCRIPT_ENTITY_STATE_CHANGE_EVENT is commonly abused; test your scripts after turning it off."));

            var lockdown = Get("sv_entityLockdown", "inactive");
            if (lockdown == "inactive" || lockdown == "")
                found.Add(new AuditFinding("low", "sv_entityLockdown", "inactive", "relaxed",
                    "Clients can create any networked entity. 'relaxed' blocks client script-created entities, but only use it when all your resources spawn entities on the server."));

            var pure = Get("sv_pureLevel", "0");
            if (pure != "1" && pure != "2")
                found.Add(new AuditFinding("low", "sv_pureLevel", pure, "1",
                    "Blocks modified client game files (level 1 still allows audio and known graphics mods)."));

            if (!Truthy(Get("sv_protectServerEntities", "false")))
                found.Add(new AuditFinding("low", "sv_protectServerEntities", "false", "true",
                    "Clients can delete entities that server scripts created (shops, job vehicles, props). Check first that no script relies on clients deleting server-spawned entities."));

            if (int.TryParse(Get("sv_requestParanoia", "0"), out var paranoia) && paranoia < 1)
                found.Add(new AuditFinding("info", "sv_requestParanoia", paranoia.ToString(), "1",
                    "Counters proxy-based HTTP floods against info/players endpoints; level 1 blocks requests carrying a 'Via' header."));

            if (int.TryParse(Get("sv_authMinTrust", "1"), out var trust) && trust <= 1)
                found.Add(new AuditFinding("info", "sv_authMinTrust", trust.ToString(), "2",
                    "Minimum trust of a player's identity provider (1–5). Raising it refuses easily spoofed identities, but can lock out some legitimate players; test before using."));

            if (Truthy(Get("sv_devMode", "false")))
                found.Add(new AuditFinding("high", "sv_devMode", "true", "false",
                    "Development mode; the FiveM docs say not to enable it in production."));

            foreach (var (name, rate, burst) in DefaultLimiters)
            {
                if (double.TryParse(Get("rateLimiter_" + name + "_rate", ""), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var r) && r > rate * 4)
                    found.Add(new AuditFinding("medium", "rateLimiter_" + name + "_rate", r.ToString(System.Globalization.CultureInfo.InvariantCulture), rate.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        $"More than 4x FiveM's default ({rate}/s): flooding {name} gets much easier. Raise it only as far as a real script needs."));
                if (double.TryParse(Get("rateLimiter_" + name + "_burst", ""), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var b) && b > burst * 4)
                    found.Add(new AuditFinding("medium", "rateLimiter_" + name + "_burst", b.ToString(System.Globalization.CultureInfo.InvariantCulture), burst.ToString(System.Globalization.CultureInfo.InvariantCulture),
                        $"More than 4x FiveM's default burst ({burst})."));
            }

            if (!Truthy(Get("sv_stateBagStrictMode", "false")))
                found.Add(new AuditFinding("info", "sv_stateBagStrictMode", "false", "true",
                    "Clients can write the state bags of entities they own and of their player; strict mode makes them server-only. Breaks scripts that set state from the client."));

            return found;
        }
    }
}
