using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using CitizenFX.Core;
using JcksAnticheat.Core.AntiDump;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private readonly Dictionary<int, HashSet<string>> _adPending = new Dictionary<int, HashSet<string>>();
        private readonly HashSet<string> _adServed = new HashSet<string>(StringComparer.Ordinal);

        private void RegisterAntiDump()
        {
            EventHandlers["jcks_anticheat:ad"] += new Action<Player, string>(OnAntiDumpRequest);
        }

        private void OnAntiDumpRequest([FromSource] Player player, string resource)
        {
            int id = ToId(player.Handle);
            if (id <= 0 || !_cfg.AntiDump.Enabled || string.IsNullOrEmpty(resource) || !_cfg.AntiDump.Resources.ContainsKey(resource)) return;
            if (!Guard(id, "antidump")) return;
            if (!_licensed || !_heartbeats.HasSession(id))
            {
                if (!_adPending.TryGetValue(id, out var set)) _adPending[id] = set = new HashSet<string>(StringComparer.Ordinal);
                if (set.Count < 64) set.Add(resource);
                return;
            }
            ServeAntiDump(player, id, resource);
        }

        private void ServePendingAntiDump(Player player, int id)
        {
            if (!_adPending.TryGetValue(id, out var set)) return;
            _adPending.Remove(id);
            foreach (var r in set) ServeAntiDump(player, id, r);
        }

        private void ServeAntiDump(Player player, int id, string resource)
        {
            if (!_adServed.Add(id + ":" + resource)) return;
            if (!_cfg.AntiDump.Resources.TryGetValue(resource, out var files)) return;
            var root = GetResourcePath(resource);
            if (string.IsNullOrEmpty(root)) return;
            var payload = new List<object?>();
            foreach (var f in files.Where(AntiDumpManifest.SafePath))
            {
                var path = Path.Combine(root, f);
                if (!File.Exists(path)) continue;
                payload.Add(new Dictionary<string, object?> { ["n"] = f, ["c"] = File.ReadAllText(path) });
            }
            TriggerLatentClientEvent(player, "jcks_anticheat:ad:" + resource, 256 * 1024, MiniJson.Serialize(payload));
        }

        private void ForgetAntiDump(int id)
        {
            _adPending.Remove(id);
            _adServed.RemoveWhere(k => k.StartsWith(id + ":", StringComparison.Ordinal));
        }

        private string AntiDumpCommand(List<object> args)
        {
            var action = args.Count > 1 ? args[1]?.ToString() ?? "status" : "status";
            var res = args.Count > 2 ? args[2]?.ToString() ?? "" : "";
            if (action == "status")
                return _cfg.AntiDump.Enabled
                    ? $"Anti-dump on for {_cfg.AntiDump.Resources.Count} resource(s): " + string.Join(", ", _cfg.AntiDump.Resources.Select(k => $"{k.Key} ({k.Value.Count} files)"))
                    : "Anti-dump is off.";
            if (string.IsNullOrEmpty(res) || res == _resource || GetResourceState(res) == "missing") return "Usage: jac antidump protect|unprotect <resource>";
            var root = GetResourcePath(res);
            var file = File.Exists(Path.Combine(root, "fxmanifest.lua")) ? "fxmanifest.lua" : "__resource.lua";
            var manifest = LoadResourceFile(res, file) ?? "";
            var edited = AnticheatConfig.Parse(MiniJson.Serialize(_cfg.ToJson()));

            if (action == "protect")
            {
                if (AntiDumpManifest.IsProtected(manifest)) return res + " is already protected.";
                var (stripped, entries) = AntiDumpManifest.Extract(manifest);
                var files = AntiDumpManifest.Expand(root, entries);
                if (files.Count == 0) return res + " has no local client .lua scripts to protect.";
                if (!ShieldInstaller.IsInstalled(stripped)) stripped = ShieldInstaller.Install(stripped + "\nclient_script 'jac_antidump_placeholder.lua'").manifest.Replace("\nclient_script 'jac_antidump_placeholder.lua'", "");
                SaveResourceFile(res, file + ".jac-ad-backup", manifest, -1);
                SaveResourceFile(res, file, stripped, -1);
                edited.AntiDump.Enabled = true;
                edited.AntiDump.Resources[res] = files;
                var msg = Apply(edited, "console (jac antidump protect)", save: true);
                return $"{res}: {files.Count} client file(s) are now served at runtime ({string.Join(", ", files.Take(10))}). {msg} Run 'refresh' and 'ensure {res}'.";
            }
            if (action == "unprotect")
            {
                var backup = LoadResourceFile(res, file + ".jac-ad-backup");
                if (string.IsNullOrEmpty(backup)) return "No backup found for " + res + " (" + file + ".jac-ad-backup).";
                SaveResourceFile(res, file, backup, -1);
                edited.AntiDump.Resources.Remove(res);
                var msg = Apply(edited, "console (jac antidump unprotect)", save: true);
                return $"{res}: manifest restored. {msg} Run 'refresh' and 'ensure {res}'.";
            }
            return "Usage: jac antidump protect|unprotect <resource> | jac antidump status";
        }
    }
}
