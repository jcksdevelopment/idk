using System;
using System.Text.RegularExpressions;

namespace JcksAnticheat.Core.Detection
{
    public static class ShieldInstaller
    {
        public const string Marker = "-- jcks_anticheat:shield";
        public const string IncludeLine = "client_script \"@jcks_anticheat/shield/shield.lua\" " + Marker + " (remove with: jac shield uninstall)";

        private static readonly Regex ClientCode = new Regex(@"^\s*(client_scripts?|shared_scripts?)\b", RegexOptions.Multiline);

        public static bool IsInstalled(string manifest) => manifest.Contains(Marker);

        public static bool HasClientCode(string manifest) => ClientCode.IsMatch(manifest);

        public static (string manifest, bool changed) Install(string manifest)
        {
            if (manifest == null || IsInstalled(manifest) || !HasClientCode(manifest)) return (manifest ?? "", false);
            var newline = manifest.Contains("\r\n") ? "\r\n" : "\n";
            return (IncludeLine + newline + manifest, true);
        }

        public static (string manifest, bool changed) Uninstall(string manifest)
        {
            if (manifest == null || !IsInstalled(manifest)) return (manifest ?? "", false);
            var lines = manifest.Split('\n');
            var kept = Array.FindAll(lines, l => !l.Contains(Marker));
            return (string.Join("\n", kept), true);
        }
    }
}
