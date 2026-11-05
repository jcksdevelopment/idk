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
        private readonly System.Collections.Concurrent.ConcurrentDictionary<int, (DateTime dropAt, string reason, bool banned)> _removing =
            new System.Collections.Concurrent.ConcurrentDictionary<int, (DateTime, string, bool)>();

        private const int KickScreenshotDelaySeconds = 6;

        private void Punish(Violation v)
        {
            if (!_licensed || _cfg.Scoring.Ignore.Contains(v.Code)) return;
            var player = Players[v.Player];
            if (player == null) return;
            if (_removing.TryGetValue(v.Player, out var leaving) && leaving.banned) return;

            _ledger.Record(v);
            bool bypass = _cfg.AdminAce.Any(ace => IsPlayerAceAllowed(player.Handle, ace) || IsPlayerAceAllowed(player.Handle, ace + "." + v.Code));
            Log($"{player.Name} {v}{(bypass ? " (bypass)" : "")}{(_cfg.DryRun ? " (dry run)" : "")}");

            _dashboard.Enqueue("detection", new Dictionary<string, object?>
            {
                ["player"] = v.Player, ["name"] = player.Name, ["code"] = v.Code, ["source"] = v.Source.ToString().ToLowerInvariant(),
                ["severity"] = v.Severity, ["score"] = Math.Round(v.ScoreAfter, 1), ["action"] = v.Action.ToString().ToLowerInvariant(),
                ["evidence"] = v.Evidence, ["bypass"] = bypass, ["dryRun"] = _cfg.DryRun,
            });

            _discord.Detection(player.Name, v.Player, v, _cfg.DryRun);
            _recent.Add(v);
            var alert = _staffAlerts.Message(player.Name, v, bypass, _cfg.DryRun, DateTime.UtcNow);
            if (alert != null) AlertStaff(alert);
            if (!bypass) ApplyServerCountermeasure(v, player.Handle);
            if (bypass || _cfg.DryRun) return;

            switch (v.Action)
            {
                case EnforcementAction.Screenshot:
                    if (_vision.IsConfigured) RequestScreenshot(v.Player, $"{v.Code} (score {v.ScoreAfter:F0})");
                    break;
                case EnforcementAction.Kick:
                    if (_removing.ContainsKey(v.Player)) break;
                    var reason = Msg(_cfg.Messages.Kick, v.Code, v.Code, null, null, player.Name);
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

        private void AlertStaff(string text)
        {
            foreach (var p in Players)
                if (IsPlayerAceAllowed(p.Handle, AdminAce) || IsPlayerAceAllowed(p.Handle, "jcks_anticheat.alerts"))
                    p.TriggerEvent("chat:addMessage", new { color = new[] { 255, 170, 60 }, args = new[] { "JCKS AC", text } });
        }

        private string Msg(string template, string? code, string? reason, string? id, string? expires, string? name)
            => _cfg.Messages.Format(template, new Dictionary<string, string?>
            {
                ["code"] = code, ["reason"] = reason, ["id"] = id, ["expires"] = expires, ["name"] = name,
            });

        private static string ExpiryText(DateTime? at) => at.HasValue ? at.Value.ToString("yyyy-MM-dd HH:mm") + " UTC" : "permanent";

        private void BanPlayer(int playerId, string code, string reason, string actor, double? durationHours = null)
        {
            var player = Players[playerId];
            if (player == null) return;
            if (_removing.TryGetValue(playerId, out var leaving) && leaving.banned) return;
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
            DropPlayer(player.Handle, Msg(_cfg.Messages.Ban, code, reason, ban.Id, ExpiryText(ban.ExpiresAt), player.Name));
        }

        private void BanOffline(DashboardCommand cmd)
        {
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

        private void ProcessScheduledDrops(DateTime now)
        {
            foreach (var kv in _removing)
            {
                if (kv.Value.banned || kv.Value.dropAt > now) continue;
                var p = Players[kv.Key];
                if (p != null) DropPlayer(p.Handle, kv.Value.reason);
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
                    if (p != null) DropPlayer(p.Handle, Msg(_cfg.Messages.StaffKick, "MANUAL", cmd.Reason ?? "no reason given", null, null, p.Name));
                    break;
                case "backdoor":
                    var bdArgs = new List<object> { "scan" };
                    if (cmd.Reason != "scan") { bdArgs.Add(cmd.Reason ?? ""); bdArgs.Add(cmd.BanId ?? ""); }
                    Log("dashboard backdoor " + cmd.Reason + ": " + BackdoorCommand(bdArgs));
                    break;
                case "integrations":
                    if (cmd.Reason == "apply" || cmd.Reason == "clear")
                        Log("dashboard integrations " + cmd.Reason + ": " + IntegrationsCommand(cmd.Reason, (cmd.Actor ?? "dashboard") + " (web, integrations apply)"));
                    break;
                case "config":
                    Log("dashboard settings: " + SaveFromJson(cmd.Config, (cmd.Actor ?? "dashboard") + " (web)"));
                    break;
                case "reload":
                    Log("dashboard reload: " + ReloadFromDisk((cmd.Actor ?? "dashboard") + " (web)"));
                    break;
                case "reset":
                    if (Players[cmd.Player] != null)
                    {
                        _ledger.Forget(cmd.Player);
                        _recent.Forget(cmd.Player);
                        Log($"score of #{cmd.Player} reset by {cmd.Actor} (web)");
                    }
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
