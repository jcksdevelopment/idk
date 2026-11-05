using System;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Validation;
using static CitizenFX.Core.Native.API;

namespace JcksAnticheat.Server
{
    public sealed partial class AnticheatScript
    {
        private static readonly System.Collections.Generic.HashSet<string> ClientCountered = new System.Collections.Generic.HashSet<string>(StringComparer.Ordinal)
        {
            "PLY_SUPERJUMP", "WPN_DMG_MODIFIER", "PLY_GODMODE_PROOFS", "PLY_HEALTH_CAP", "MOV_NOCLIP_COLLISION", "PLY_GODMODE_FLAG", "PLY_INVISIBLE",
        };

        private bool CountermeasuresActive => _cfg.Countermeasures.Enabled && (!_cfg.DryRun || _cfg.Countermeasures.ApplyInDryRun);

        private bool CountermeasureOn(string code) => CountermeasuresActive && !_cfg.Countermeasures.Skip.Contains(code);

        private void ApplyServerCountermeasure(Violation v, string handle)
        {
            if (!CountermeasureOn(v.Code)) return;
            int ped = GetPlayerPed(handle);
            if (ped == 0) return;
            switch (v.Code)
            {
                case "MOV_TELEPORT":
                case "PLY_SPEED_FOOT":
                case "MOV_SPEED_VEH":
                case "MOV_NOCLIP_ZVEL":
                    PutBack(v.Player, ped);
                    break;
                case "VEH_HIJACK":
                    int veh = GetVehiclePedIsIn(ped, false);
                    if (veh != 0) TaskLeaveVehicle(ped, veh, 16);
                    break;
                case "PLY_GODMODE_FLAG":
                    SetPlayerInvincible(handle, false);
                    break;
                case "WPN_GIVE_ALL":
                    RemoveAllPedWeapons(ped, true);
                    break;
                case "ENT_ATTACH_PLAYER":
                    foreach (var e in _attachRemoval ?? new System.Collections.Generic.List<int>())
                        if (DoesEntityExist(e)) DeleteEntity(e);
                    break;
            }
            if (ClientCountered.Contains(v.Code) && v.Source == ViolationSource.Server)
                Players[v.Player]?.TriggerEvent(_counterEvent, v.Code);
        }

        private void PutBack(int player, int ped)
        {
            var good = _movement.LastGood(player);
            if (good == null) return;
            int veh = GetVehiclePedIsIn(ped, false);
            int subject = veh != 0 ? veh : ped;
            var p = good.Value;
            SetEntityVelocity(subject, 0f, 0f, 0f);
            SetEntityCoords(subject, p.X, p.Y, p.Z, false, false, false, false);
            _movement.GrantGrace(player, TimeSpan.FromSeconds(3));
        }
    }
}
