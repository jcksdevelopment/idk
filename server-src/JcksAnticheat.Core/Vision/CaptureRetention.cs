using System;
using System.IO;
using System.Linq;

namespace JcksAnticheat.Core.Vision
{
    public static class CaptureRetention
    {
        public static int Enforce(string directory, int keep, string pattern = "*.jpg")
        {
            if (keep < 0 || !Directory.Exists(directory)) return 0;
            var old = new DirectoryInfo(directory).GetFiles(pattern)
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .Skip(keep)
                .ToList();
            int deleted = 0;
            foreach (var f in old)
            {
                try { f.Delete(); deleted++; }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            return deleted;
        }
    }
}
