using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace JcksAnticheat.Core.Messages
{
    public sealed class MessageSettings
    {
        public string Kick { get; set; } = "[JCKS Anticheat] Disconnected: suspicious activity ({code}).";
        public string Ban { get; set; } = "[JCKS Anticheat] Banned. Reason: {reason} | Ban ID: {id}{appeal}";
        public string Banned { get; set; } = "[JCKS Anticheat] You are banned. Reason: {reason} | Ban ID: {id} | Expires: {expires}{appeal}";
        public string StaffKick { get; set; } = "[JCKS Anticheat] Kicked by staff: {reason}";
        public string NameRejected { get; set; } = "[JCKS Anticheat] {reason} Change your FiveM name and reconnect.";
        public string AppealUrl { get; set; } = "";

        private static readonly Regex Placeholder = new Regex(@"\{([a-z]+)\}", RegexOptions.Compiled);

        public string Format(string template, IDictionary<string, string?> values)
        {
            var text = Placeholder.Replace(template ?? "", m =>
            {
                var key = m.Groups[1].Value;
                if (key == "appeal") return string.IsNullOrWhiteSpace(AppealUrl) ? "" : " | Appeal: " + AppealUrl;
                return values.TryGetValue(key, out var v) ? v ?? "" : m.Value;
            });
            text = text.Replace("\r", " ").Replace("\n", " ");
            return text.Length > 512 ? text.Substring(0, 512) : text;
        }

        public static readonly string[] Keys = { "kick", "ban", "banned", "staffKick", "nameRejected" };
    }
}
