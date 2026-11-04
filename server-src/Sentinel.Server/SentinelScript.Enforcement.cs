using System;
using System.Collections.Generic;
using System.Linq;
using CitizenFX.Core;
using Sentinel.Core.Bans;
using Sentinel.Core.Dashboard;
using Sentinel.Core.Detection;
using static CitizenFX.Core.Native.API;

namespace Sentinel.Server
{
    public sealed partial class SentinelScript
    {
        private void Punish(Violation v)
        {
            var player = Players[v.Player];
            if (player == null) return;

            _ledger.Record(v);
            bool bypass = _cfg.AdminAce.Any(ace => IsPlayerAceAllowed(player.Handle, ace));
            Log($"{player.Name} {v}{(bypass ? " (bypass)" : "")}{(_cfg.DryRun ? " (dry run)" : "")}");

            _dashboard.Enqueue("detection", new Dictionary<string, object?>
            {
                ["player"] = v.Player, ["name"] = player.Name, ["code"] = v.Code, ["source"] = v.Source.ToString().ToLowerInvariant(),
                ["severity"] = v.Severity, ["score"] = Math.Round(v.ScoreAfter, 1), ["action"] = v.Action.ToString().ToLowerInvariant(),
                ["evidence"] = v.Evidence, ["bypass"] = bypass, ["dryRun"] = _cfg.DryRun,
            });

            if (bypass || _cfg.DryRun) return;

            switch (v.Action)
            {
                case EnforcementAction.Screenshot:
                    if (_vision.IsConfigured) RequestScreenshot(v.Player, $"{v.Code} (score {v.ScoreAfter:F0})");
                    break;
                case EnforcementAction.Kick:
                    if (_vision.IsConfigured) RequestScreenshot(v.Player, $"{v.Code} before kick");
                    DropPlayer(player.Handle, $"[Sentinel] Disconnected: suspicious activity ({v.Code}).");
                    break;
                case EnforcementAction.Ban:
                    BanPlayer(v.Player, v.Code, $"Automated: {v.Code}", "sentinel");
                    break;
            }
        }

        private void BanPlayer(int playerId, string code, string reason, string actor, double? durationHours = null)
        {
            var player = Players[playerId];
            if (player == null) return;
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
            DropPlayer(player.Handle, $"[Sentinel] Banned. Reason: {reason} | Ban ID: {ban.Id}");
        }

        private void ExecuteCommand(DashboardCommand cmd)
        {
            Log($"dashboard command {cmd.Type} player={cmd.Player} ban={cmd.BanId} by {cmd.Actor}");
            switch (cmd.Type)
            {
                case "ban":
                    BanPlayer(cmd.Player, "MANUAL", cmd.Reason ?? "Banned by staff", cmd.Actor ?? "dashboard", cmd.DurationHours);
                    break;
                case "unban":
                    if (cmd.BanId != null && _bans.Remove(cmd.BanId))
                        _dashboard.Enqueue("unban", new Dictionary<string, object?> { ["id"] = cmd.BanId, ["actor"] = cmd.Actor });
                    break;
                case "kick":
                    var p = Players[cmd.Player];
                    if (p != null) DropPlayer(p.Handle, "[Sentinel] Kicked by staff: " + (cmd.Reason ?? "no reason given"));
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
