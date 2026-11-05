using System;
using System.Collections.Generic;
using System.Linq;
using CitizenFX.Core;
using JcksAnticheat.Core.Bans;
using JcksAnticheat.Core.Dashboard;
using JcksAnticheat.Core.Detection;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        /// <summary>Players already on their way out (kick scheduled or ban issued): no repeat actions.</summary>
        private readonly System.Collections.Concurrent.ConcurrentDictionary<int, (DateTime dropAt, string reason, bool banned)> _removing =
            new System.Collections.Concurrent.ConcurrentDictionary<int, (DateTime, string, bool)>();

        /// <summary>Seconds a score-based kick waits so the requested screenshot can arrive first.</summary>
        private const int KickScreenshotDelaySeconds = 6;

        private void Punish(Violation v)
        {
            if (_cfg.Scoring.Ignore.Contains(v.Code)) return;
            var player = Players[v.Player];
            if (player == null) return;
            if (_removing.TryGetValue(v.Player, out var leaving) && leaving.banned) return; // already banned

            _ledger.Record(v);
            bool bypass = _cfg.AdminAce.Any(ace => IsPlayerAceAllowed(player.Handle, ace));
            Log($"{player.Name} {v}{(bypass ? " (bypass)" : "")}{(_cfg.DryRun ? " (dry run)" : "")}");

            _dashboard.Enqueue("detection", new Dictionary<string, object?>
            {
                ["player"] = v.Player, ["name"] = player.Name, ["code"] = v.Code, ["source"] = v.Source.ToString().ToLowerInvariant(),
                ["severity"] = v.Severity, ["score"] = Math.Round(v.ScoreAfter, 1), ["action"] = v.Action.ToString().ToLowerInvariant(),
                ["evidence"] = v.Evidence, ["bypass"] = bypass, ["dryRun"] = _cfg.DryRun,
            });

            _discord.Detection(player.Name, v.Player, v, _cfg.DryRun);
            if (!bypass) ApplyServerCountermeasure(v, player.Handle);
            if (bypass || _cfg.DryRun) return;

            switch (v.Action)
            {
                case EnforcementAction.Screenshot:
                    if (_vision.IsConfigured) RequestScreenshot(v.Player, $"{v.Code} (score {v.ScoreAfter:F0})");
                    break;
                case EnforcementAction.Kick:
                    if (_removing.ContainsKey(v.Player)) break; // kick already scheduled
                    var reason = $"[JCKS Anticheat] Disconnected: suspicious activity ({v.Code}).";
                    // Heartbeat failures and floods leave at once: the scanner is dead or the client is
                    // spamming, so a screenshot is pointless. Score-based kicks wait a few seconds so the
                    // capture requested now can reach the server before the connection closes.
                    bool screenshot = _vision.IsConfigured && !_cfg.Scoring.DropImmediately.Contains(v.Code);
                    if (screenshot) RequestScreenshot(v.Player, $"{v.Code} before kick");
                    _removing[v.Player] = (DateTime.UtcNow.AddSeconds(screenshot ? KickScreenshotDelaySeconds : 0), reason, false);
                    if (!screenshot) DropPlayer(player.Handle, reason);
                    break;
                case EnforcementAction.Ban:
                    BanPlayer(v.Player, v.Code, $"Automated: {v.Code}", "jcks_anticheat");
                    break;
            }
        }

        private void BanPlayer(int playerId, string code, string reason, string actor, double? durationHours = null)
        {
            var player = Players[playerId];
            if (player == null) return;
            if (_removing.TryGetValue(playerId, out var leaving) && leaving.banned) return; // one ban per player
            _removing[playerId] = (DateTime.UtcNow, reason, true);
            var ban = _bans.Add(new Ban
            {
                Name = player.Name,
                Identifiers = IdentifiersOf(player.Handle),
                Reason = reason,
                Code = code,
                BannedBy = actor,
                ExpiresAt = durationHours.HasValue && durationHours > 0 ? DateTime.UtcNow.AddHours(durationHours.Value) : (DateTime?)null,
            });
            _dashboard.Enqueue("ban", ban);
            _discord.Ban(ban.Name, ban.Id, reason, actor, ban.ExpiresAt);
            DropPlayer(player.Handle, $"[JCKS Anticheat] Banned. Reason: {reason} | Ban ID: {ban.Id}");
        }

        /// <summary>The player left before the moderator acted: ban the identifiers the dashboard recorded.</summary>
        private void BanOffline(DashboardCommand cmd)
        {
            // The dashboard never sees tokens or IPs, so offline bans cover license/discord/fivem/steam only.
            var ban = _bans.Add(new Ban
            {
                Name = cmd.Name ?? ("#" + cmd.Player),
                Identifiers = cmd.Identifiers.Where(i => i.IndexOf(':') > 0).Take(32).ToList(),
                Reason = cmd.Reason ?? "Banned by staff",
                Code = "MANUAL",
                BannedBy = cmd.Actor ?? "dashboard",
                ExpiresAt = cmd.DurationHours.HasValue && cmd.DurationHours > 0 ? DateTime.UtcNow.AddHours(cmd.DurationHours.Value) : (DateTime?)null,
            });
            _dashboard.Enqueue("ban", ban);
        }

        /// <summary>Runs scheduled kicks whose screenshot window has passed. Called from the tick.</summary>
        private void ProcessScheduledDrops(DateTime now)
        {
            foreach (var kv in _removing)
            {
                if (kv.Value.banned || kv.Value.dropAt > now) continue;
                var p = Players[kv.Key];
                if (p != null) DropPlayer(p.Handle, kv.Value.reason);
                // Keep the entry until playerDropped so later violations don't schedule a second kick.
                _removing[kv.Key] = (DateTime.MaxValue, kv.Value.reason, false);
            }
        }

        private void ExecuteCommand(DashboardCommand cmd)
        {
            Log($"dashboard command {cmd.Type} player={cmd.Player} ban={cmd.BanId} by {cmd.Actor}");
            switch (cmd.Type)
            {
                case "ban":
                    if (Players[cmd.Player] != null)
                        BanPlayer(cmd.Player, "MANUAL", cmd.Reason ?? "Banned by staff", cmd.Actor ?? "dashboard", cmd.DurationHours);
                    else if (cmd.Identifiers.Count > 0)
                        BanOffline(cmd);
                    break;
                case "unban":
                    if (cmd.BanId != null && _bans.Remove(cmd.BanId))
                        _dashboard.Enqueue("unban", new Dictionary<string, object?> { ["id"] = cmd.BanId, ["actor"] = cmd.Actor });
                    break;
                case "kick":
                    var p = Players[cmd.Player];
                    if (p != null) DropPlayer(p.Handle, "[JCKS Anticheat] Kicked by staff: " + (cmd.Reason ?? "no reason given"));
                    break;
                case "config":
                    Log("dashboard settings: " + SaveFromJson(cmd.Config, (cmd.Actor ?? "dashboard") + " (web)"));
                    break;
                case "reload":
                    Log("dashboard reload: " + ReloadFromDisk((cmd.Actor ?? "dashboard") + " (web)"));
                    break;
                case "screenshot":
                    _lastCapture.TryRemove(cmd.Player, out _);
                    RequestScreenshot(cmd.Player, "manual request by " + (cmd.Actor ?? "staff"));
                    break;
            }
        }

        private Dictionary<string, object?> PlayerSnapshot(Player p)
        {
            int id = ToId(p.Handle);
            var hb = _heartbeats.Get(id);
            return new Dictionary<string, object?>
            {
                ["id"] = id,
                ["name"] = p.Name,
                ["identifiers"] = IdentifiersOf(p.Handle).Where(i => !i.StartsWith("ip:") && !i.StartsWith("token:")).ToList(),
                ["ping"] = GetPlayerPing(p.Handle),
                ["score"] = Math.Round(_ledger.ScoreOf(id), 1),
                ["heartbeat"] = hb == null ? null : (object)new Dictionary<string, object?>
                {
                    ["seq"] = hb.Sequence, ["lastValidAt"] = hb.LastValidAt, ["failures"] = hb.Failures,
                },
            };
        }
    }
}
