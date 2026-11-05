using System;
using JcksAnticheat.Core.Detection;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private readonly GraceDeferral _deferral = new GraceDeferral();

        private static string? GraceKindFor(string code) => GraceDeferral.KindFor(code);

        private void Defer(int player, string kind, DateTime now, Violation? violation, Action? countermeasure)
            => _deferral.Add(player, kind, now, violation, countermeasure);

        private void RecordGrant(int player, string kind, DateTime at) => _deferral.RecordGrant(player, kind, at);

        private void ResolveDeferred(DateTime now)
        {
            if (_deferral.Pending == 0) return;
            foreach (var d in _deferral.Resolve(now, p => Players[p] != null))
            {
                d.Countermeasure?.Invoke();
                if (d.Violation != null) Punish(d.Violation);
            }
        }

        private void ForgetDeferred(int player) => _deferral.Forget(player);
    }
}
