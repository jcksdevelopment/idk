using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace JcksAnticheat.Core.Backdoor
{
    public enum Severity { Low = 1, Medium = 2, High = 3 }

    public sealed class Finding
    {
        public string Id { get; set; } = "";
        public string Resource { get; set; } = "";
        public string File { get; set; } = "";
        public string FullPath { get; set; } = "";
        public int Line { get; set; }
        public string Rule { get; set; } = "";
        public Severity Severity { get; set; }
        public string Description { get; set; } = "";
        public string Snippet { get; set; } = "";
    }

    public sealed class ScanOptions
    {
        public long MaxFileBytes { get; set; } = 2 * 1024 * 1024;
        public HashSet<string> IgnoreIds { get; set; } = new HashSet<string>(StringComparer.Ordinal);
        public HashSet<string> IgnoreResources { get; set; } = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> DisabledRules { get; set; } = new HashSet<string>(StringComparer.Ordinal);
    }

    public static class BackdoorScanner
    {
        private sealed class LineRule
        {
            public LineRule(string id, Severity severity, string description, string extensions, Regex pattern, Regex? fileRequires = null)
            {
                Id = id; Severity = severity; Description = description; Extensions = extensions.Split(','); Pattern = pattern; FileRequires = fileRequires;
            }
            public string Id { get; }
            public Severity Severity { get; }
            public string Description { get; }
            public string[] Extensions { get; }
            public Regex Pattern { get; }
            public Regex? FileRequires { get; }
        }

        private const RegexOptions Opts = RegexOptions.Compiled | RegexOptions.CultureInvariant;

        private static readonly Regex HttpLua = new Regex(@"PerformHttpRequest\s*\(", Opts);
        private static readonly Regex HttpJs = new Regex(@"\bfetch\s*\(|require\s*\(\s*['""`](https?|axios|node-fetch|request)['""`]\s*\)|PerformHttpRequest\s*\(|\bXMLHttpRequest\b", Opts);

        private static readonly LineRule[] Rules =
        {
            new LineRule("LUA_REMOTE_LOAD", Severity.High, "Code downloaded over HTTP is executed with load()", ".lua",
                new Regex(@"\b(load|loadstring)\s*\(", Opts), HttpLua),
            new LineRule("JS_REMOTE_EVAL", Severity.High, "Code downloaded over HTTP is executed with eval/Function", ".js",
                new Regex(@"\beval\s*\(|\bnew\s+Function\s*\(|\bFunction\s*\(\s*['""`]", Opts), HttpJs),
            new LineRule("SHELL_EXEC", Severity.High, "Runs operating-system commands", ".lua,.js",
                new Regex(@"\bos\.execute\s*\(|\bio\.popen\s*\(|require\s*\(\s*['""`]child_process['""`]\s*\)|\bexecSync\s*\(|\bspawnSync\s*\(", Opts)),
            new LineRule("SECRET_CONVAR", Severity.High, "Reads a server secret (license key, rcon password, API keys)", ".lua,.js,.cs",
                new Regex(@"GetConvar\s*\(\s*['""`](sv_licenseKey|rcon_password|steam_webApiKey|sv_tebexSecret|txAdmin-luaComToken)['""`]", Opts | RegexOptions.IgnoreCase)),
            new LineRule("ACE_GRANT", Severity.Medium, "Grants ACE permissions from code", ".lua,.js",
                new Regex(@"ExecuteCommand\s*\(\s*['""`]\s*(add_ace|add_principal|remove_principal)\b", Opts)),
            new LineRule("MANIFEST_WRITE", Severity.High, "Writes into a resource manifest (self-propagation)", ".lua,.js",
                new Regex(@"SaveResourceFile\s*\([^\n]*(fxmanifest|__resource)", Opts)),
            new LineRule("FS_WRITE_OTHER", Severity.Medium, "Writes files outside its own resource", ".js",
                new Regex(@"\b(writeFileSync|appendFileSync|writeFile)\s*\([^\n]*(\.\./|resources[/\\]|server\.cfg)", Opts)),
            new LineRule("ENCODED_PAYLOAD", Severity.Medium, "Long run of escaped bytes (hidden payload)", ".lua,.js",
                new Regex(@"(\\x[0-9a-fA-F]{2}|\\[0-9]{1,3}){60,}", Opts)),
            new LineRule("LOAD_ENCODED", Severity.High, "Executes code built from encoded bytes", ".lua",
                new Regex(@"\b(load|loadstring)\s*\(\s*(string\.char|\(?\s*['""]\\(x[0-9a-fA-F]{2}|[0-9]{1,3}))", Opts)),
            new LineRule("CFG_READ", Severity.Medium, "Reads server.cfg (contains license key and passwords)", ".lua,.js",
                new Regex(@"(io\.open|readFileSync|readFile|LoadResourceFile)\s*\([^\n]*server\.cfg", Opts)),
        };

        private static readonly Regex JsObfuscatorName = new Regex(@"\b_0x[0-9a-f]{4,6}\b", Opts);

        public static IReadOnlyList<string> RuleIds => Rules.Select(r => r.Id).Concat(new[] { "JS_OBFUSCATED", "HUGE_LINE" }).ToList();

        /// <summary>Scans one resource folder. resourceName is used for reporting and ignore rules.</summary>
        public static List<Finding> ScanResource(string resourceName, string root, ScanOptions options)
        {
            var findings = new List<Finding>();
            if (options.IgnoreResources.Contains(resourceName) || !Directory.Exists(root)) return findings;
            foreach (var path in SafeEnumerate(root))
            {
                var ext = Path.GetExtension(path).ToLowerInvariant();
                if (ext != ".lua" && ext != ".js" && ext != ".cs") continue;
                FileInfo info;
                try { info = new FileInfo(path); } catch { continue; }
                if (info.Length == 0 || info.Length > options.MaxFileBytes) continue;
                string text;
                try { text = File.ReadAllText(path); } catch { continue; }
                if (LooksBinary(text)) continue;
                var rel = MakeRelative(root, path);
                findings.AddRange(ScanText(resourceName, rel, path, text, options));
            }
            return findings;
        }

        public static List<Finding> ScanText(string resource, string relativeFile, string fullPath, string text, ScanOptions options)
        {
            var findings = new List<Finding>();
            var ext = Path.GetExtension(relativeFile).ToLowerInvariant();
            var lines = text.Split('\n');

            foreach (var rule in Rules)
            {
                if (options.DisabledRules.Contains(rule.Id) || !rule.Extensions.Contains(ext)) continue;
                if (rule.FileRequires != null && !rule.FileRequires.IsMatch(text)) continue;
                for (int i = 0; i < lines.Length; i++)
                {
                    var line = lines[i];
                    if (line.Length > 20000) line = line.Substring(0, 20000);
                    if (IsCommentOnly(line, ext) || !rule.Pattern.IsMatch(line)) continue;
                    Add(findings, options, resource, relativeFile, fullPath, i + 1, rule.Id, rule.Severity, rule.Description, lines[i]);
                }
            }

            if (ext == ".js" && !options.DisabledRules.Contains("JS_OBFUSCATED"))
            {
                int names = JsObfuscatorName.Matches(text).Count;
                if (names >= 25)
                {
                    int first = Array.FindIndex(lines, l => JsObfuscatorName.IsMatch(l));
                    Add(findings, options, resource, relativeFile, fullPath, first + 1, "JS_OBFUSCATED", Severity.Medium,
                        $"javascript-obfuscator style code ({names} _0x names)", lines[Math.Max(0, first)]);
                }
            }

            if (ext == ".lua" && !options.DisabledRules.Contains("HUGE_LINE"))
            {
                int idx = Array.FindIndex(lines, l => l.Length > 8000);
                if (idx >= 0)
                    Add(findings, options, resource, relativeFile, fullPath, idx + 1, "HUGE_LINE", Severity.Low,
                        $"Single line of {lines[idx].Length} characters (packed or obfuscated code)", lines[idx]);
            }

            return findings;
        }

        private static void Add(List<Finding> list, ScanOptions o, string resource, string file, string full, int line, string rule, Severity sev, string desc, string raw)
        {
            var snippet = raw.Trim();
            if (snippet.Length > 140) snippet = snippet.Substring(0, 140) + "…";
            var id = StableId(resource, file, rule, raw.Trim());
            if (o.IgnoreIds.Contains(id)) return;
            if (list.Any(f => f.Id == id)) return;
            list.Add(new Finding { Id = id, Resource = resource, File = file, FullPath = full, Line = line, Rule = rule, Severity = sev, Description = desc, Snippet = snippet });
        }

        public static string StableId(string resource, string file, string rule, string content)
        {
            using (var sha = SHA256.Create())
            {
                var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(resource + "|" + file.Replace('\\', '/') + "|" + rule + "|" + content));
                return BitConverter.ToString(bytes, 0, 4).Replace("-", "").ToLowerInvariant();
            }
        }

        private static bool IsCommentOnly(string line, string ext)
        {
            var t = line.TrimStart();
            return ext == ".lua" ? t.StartsWith("--", StringComparison.Ordinal) : t.StartsWith("//", StringComparison.Ordinal) || t.StartsWith("*", StringComparison.Ordinal);
        }

        private static bool LooksBinary(string text)
        {
            int n = Math.Min(text.Length, 4000);
            for (int i = 0; i < n; i++) if (text[i] == '\0') return true;
            return text.StartsWith("FXAP", StringComparison.Ordinal);
        }

        private static IEnumerable<string> SafeEnumerate(string root)
        {
            var stack = new Stack<string>();
            stack.Push(root);
            while (stack.Count > 0)
            {
                var dir = stack.Pop();
                string[] files, dirs;
                try { files = Directory.GetFiles(dir); dirs = Directory.GetDirectories(dir); } catch { continue; }
                foreach (var f in files) yield return f;
                foreach (var d in dirs)
                {
                    var name = Path.GetFileName(d);
                    if (name == ".git" || name == ".jac-quarantine") continue;
                    stack.Push(d);
                }
            }
        }

        private static string MakeRelative(string root, string path)
        {
            var r = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, '/') + Path.DirectorySeparatorChar;
            var p = Path.GetFullPath(path);
            return (p.StartsWith(r, StringComparison.Ordinal) ? p.Substring(r.Length) : p).Replace('\\', '/');
        }
    }

    public static class BackdoorRemover
    {
        /// <summary>Deletes the flagged line (backup kept as file.jac-bak). Returns false if the line no longer matches.</summary>
        public static bool RemoveLine(Finding f, out string message)
        {
            try
            {
                var text = File.ReadAllText(f.FullPath);
                var lines = text.Split('\n').ToList();
                int idx = f.Line - 1;
                if (idx < 0 || idx >= lines.Count || BackdoorScanner.StableId(f.Resource, f.File, f.Rule, lines[idx].Trim()) != f.Id)
                {
                    idx = lines.FindIndex(l => BackdoorScanner.StableId(f.Resource, f.File, f.Rule, l.Trim()) == f.Id);
                    if (idx < 0) { message = "the flagged line is no longer in the file; rescan"; return false; }
                }
                File.WriteAllText(f.FullPath + ".jac-bak", text);
                lines.RemoveAt(idx);
                File.WriteAllText(f.FullPath, string.Join("\n", lines));
                message = $"removed line {idx + 1} of {f.Resource}/{f.File} (backup: {f.File}.jac-bak)";
                return true;
            }
            catch (Exception ex) { message = ex.Message; return false; }
        }

        /// <summary>Moves the whole file into resource/.jac-quarantine/ so it can't load.</summary>
        public static bool Quarantine(Finding f, string resourceRoot, out string message)
        {
            try
            {
                var dir = Path.Combine(resourceRoot, ".jac-quarantine", Path.GetDirectoryName(f.File) ?? "");
                Directory.CreateDirectory(dir);
                var target = Path.Combine(dir, Path.GetFileName(f.File));
                if (File.Exists(target)) File.Delete(target);
                File.Move(f.FullPath, target);
                message = $"moved {f.Resource}/{f.File} to {f.Resource}/.jac-quarantine/ (the resource may fail to start until you fix it)";
                return true;
            }
            catch (Exception ex) { message = ex.Message; return false; }
        }
    }
}
