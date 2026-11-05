using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace JcksAnticheat.Core.Validation
{
    public static class NameFilter
    {
        private static readonly Regex Html = new Regex(@"</?[a-zA-Z!][^>]*>|<script|javascript:|\bon[a-z]+\s*=", RegexOptions.IgnoreCase);

        public static string? Check(string? name, bool blockHtml, IEnumerable<string> blacklist)
        {
            if (string.IsNullOrWhiteSpace(name)) return "Your name is empty.";
            if (blockHtml && Html.IsMatch(name)) return "Your name contains HTML or script, which isn't allowed.";
            var lower = name!.ToLowerInvariant();
            var hit = blacklist.FirstOrDefault(w => !string.IsNullOrWhiteSpace(w) && lower.Contains(w.Trim().ToLowerInvariant()));
            return hit != null ? "Your name contains a blocked word." : null;
        }
    }
}
