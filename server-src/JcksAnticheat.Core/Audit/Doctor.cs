using System.Collections.Generic;

namespace JcksAnticheat.Core.Audit
{
    public sealed class DoctorInput
    {
        public string OneSync { get; set; } = "off";
        public int ShieldedResources { get; set; }
        public int ResourcesWithClientCode { get; set; }
        public bool VisionEnabled { get; set; }
        public bool VisionKeySet { get; set; }
        public bool ScreenshotBasicStarted { get; set; }
        public bool DashboardEnabled { get; set; }
        public bool DashboardSecretSet { get; set; }
        public bool DiscordEnabled { get; set; }
        public bool DiscordUrlSet { get; set; }
        public bool LicenseRequired { get; set; }
        public bool Licensed { get; set; }
        public bool DryRun { get; set; }
        public bool Countermeasures { get; set; }
    }

    public static class Doctor
    {
        public static List<(string level, string text)> Check(DoctorInput i)
        {
            var r = new List<(string, string)>();
            void Add(string level, string text) => r.Add((level, text));

            if (i.LicenseRequired && !i.Licensed) Add("fail", "License is not valid: detections are paused. Check jcks_ac_license in server.cfg.");
            if (i.OneSync.Trim().ToLowerInvariant() != "on") Add("fail", "OneSync is not 'on': server-side checks have no data. Add 'set onesync on' to server.cfg.");
            else Add("ok", "OneSync is on.");

            if (i.ResourcesWithClientCode > 0 && i.ShieldedResources == 0)
                Add("warn", "The shield is in no resource, so Lua executors injecting into resources are not seen and legitimate heals/teleports can't be told apart. Run 'jac shield install'.");
            else if (i.ShieldedResources < i.ResourcesWithClientCode)
                Add("warn", $"The shield is in {i.ShieldedResources} of {i.ResourcesWithClientCode} resources with client code. Run 'jac shield install' and restart.");
            else if (i.ResourcesWithClientCode > 0) Add("ok", "The shield is in every resource with client code.");

            if (i.VisionEnabled && !i.VisionKeySet) Add("warn", "vision.enabled is on but the API key environment variable is empty; AI vision is off.");
            if (i.VisionEnabled && !i.ScreenshotBasicStarted) Add("warn", "vision.enabled is on but screenshot-basic is not started; no captures can be taken.");
            if (i.DashboardEnabled && !i.DashboardSecretSet) Add("warn", "dashboard.enabled is on but the dashboard secret environment variable is empty; nothing is sent.");
            if (i.DiscordEnabled && !i.DiscordUrlSet) Add("warn", "discord.enabled is on but the webhook environment variable is empty.");
            if (i.DryRun) Add("info", "dryRun is on: nobody is kicked or banned (countermeasures still apply). Turn it off once the logs look clean.");
            if (!i.Countermeasures) Add("info", "Countermeasures are off: cheat effects are only reported, not undone.");
            return r;
        }
    }
}
