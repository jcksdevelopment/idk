using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace JcksAnticheat.Core.AntiDump
{
    public static class AntiDumpManifest
    {
        public const string Marker = "jac_antidump 'yes'";

        private static readonly Regex Single = new Regex(@"^\s*client_script\s*\(?\s*['""]([^'""]+)['""]\s*\)?\s*$", RegexOptions.Multiline);
        private static readonly Regex Block = new Regex(@"^\s*client_scripts\s*\{([^}]*)\}\s*$", RegexOptions.Multiline | RegexOptions.Singleline);
        private static readonly Regex Quoted = new Regex(@"['""]([^'""]+)['""]");

        public static bool IsProtected(string manifest) => manifest.Contains(Marker);

        public static (string manifest, List<string> entries) Extract(string manifest)
        {
            var entries = new List<string>();
            var result = Block.Replace(manifest, m =>
            {
                var items = Quoted.Matches(m.Groups[1].Value).Cast<Match>().Select(x => x.Groups[1].Value).ToList();
                var keep = items.Where(i => i.StartsWith("@", StringComparison.Ordinal) || !i.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)).ToList();
                entries.AddRange(items.Except(keep));
                return keep.Count == 0 ? "" : "client_scripts {\n" + string.Join(",\n", keep.Select(k => "  '" + k + "'")) + "\n}";
            });
            result = Single.Replace(result, m =>
            {
                var file = m.Groups[1].Value;
                if (file.StartsWith("@", StringComparison.Ordinal) || !file.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)) return m.Value;
                entries.Add(file);
                return "";
            });
            if (entries.Count > 0) result = result.TrimEnd() + "\n" + Marker + "\n";
            return (result, entries);
        }

        public static List<string> Expand(string root, IEnumerable<string> entries)
        {
            var files = new List<string>();
            foreach (var e in entries)
            {
                var entry = e.Replace('\\', '/');
                if (entry.Contains("..")) continue;
                if (!entry.Contains("*"))
                {
                    if (File.Exists(Path.Combine(root, entry))) files.Add(entry);
                    continue;
                }
                var dir = entry.Substring(0, Math.Max(0, entry.LastIndexOf('/')));
                var recursive = entry.Contains("**");
                var baseDir = Path.Combine(root, dir.Replace("**", "").TrimEnd('/'));
                if (!Directory.Exists(baseDir)) continue;
                foreach (var f in Directory.GetFiles(baseDir, "*.lua", recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly).OrderBy(x => x, StringComparer.Ordinal))
                    files.Add(f.Substring(root.TrimEnd('/', '\\').Length + 1).Replace('\\', '/'));
            }
            return files.Distinct().ToList();
        }

        public static bool SafePath(string file) => !file.Contains("..") && !Path.IsPathRooted(file) && file.EndsWith(".lua", StringComparison.OrdinalIgnoreCase);
    }
}
