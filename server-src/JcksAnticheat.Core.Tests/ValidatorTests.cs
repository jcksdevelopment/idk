using JcksAnticheat.Core.Bans;
using JcksAnticheat.Core.Config;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Json;
using JcksAnticheat.Core.Validation;
using Xunit;

namespace JcksAnticheat.Core.Tests;

public class ValidatorTests
{
    private static readonly DateTime T0 = new(2026, 11, 4, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void JoaatMatchesGameHashes()
    {
        Assert.Equal(0x1B06D571u, Joaat.Hash("WEAPON_PISTOL"));
        Assert.Equal(0xBFEFFF6Du, Joaat.Hash("weapon_assaultrifle"));
        Assert.Equal(0x1B06D571u, Joaat.FromSigned(453432689));
    }

    [Fact]
    public void TeleportIsDetectedButNormalDrivingIsNot()
    {
        var mv = new MovementValidator(new MovementLimits());
        Assert.Empty(mv.Evaluate(1, new MovementSample(new Vec3(0, 0, 0), default, MovementMode.LandVehicle, T0)));
        Assert.Empty(mv.Evaluate(1, new MovementSample(new Vec3(60, 0, 0), default, MovementMode.LandVehicle, T0.AddSeconds(1))));
        var tp = mv.Evaluate(1, new MovementSample(new Vec3(2000, 0, 0), default, MovementMode.LandVehicle, T0.AddSeconds(2)));
        Assert.Contains(tp, v => v.Code == "MOV_TELEPORT");
    }

    [Fact]
    public void FallingIsFreeButFlyingUpOnFootIsNot()
    {
        var mv = new MovementValidator(new MovementLimits());
        mv.Evaluate(2, new MovementSample(new Vec3(0, 0, 500), default, MovementMode.OnFoot, T0));
        Assert.Empty(mv.Evaluate(2, new MovementSample(new Vec3(0, 0, 450), default, MovementMode.OnFoot, T0.AddSeconds(1))));
        var up = mv.Evaluate(2, new MovementSample(new Vec3(0, 0, 480), default, MovementMode.OnFoot, T0.AddSeconds(2)));
        Assert.Contains(up, v => v.Code == "MOV_NOCLIP_ZVEL");
    }

    [Fact]
    public void TeleportGraceSuppressesDetection()
    {
        var mv = new MovementValidator(new MovementLimits());
        mv.Evaluate(3, new MovementSample(new Vec3(0, 0, 0), default, MovementMode.OnFoot, T0));
        mv.GrantGrace(3, TimeSpan.FromSeconds(5), T0);
        Assert.Empty(mv.Evaluate(3, new MovementSample(new Vec3(3000, 0, 0), default, MovementMode.OnFoot, T0.AddSeconds(1))));
    }

    private static WeaponHit Hit(float damage = 26, float heading = 0, float victimY = 30, bool head = false, DateTime? at = null) => new()
    {
        Attacker = 1, VictimPlayer = 2, WeaponHash = Joaat.Hash("WEAPON_PISTOL"), Damage = damage, Headshot = head,
        AttackerPos = new Vec3(0, 0, 0), AttackerHeading = heading, VictimPos = new Vec3(0, victimY, 0), At = at ?? T0,
    };

    [Fact]
    public void LegitHitPasses() => Assert.Empty(new DamageValidator(new DamageLimits()).Evaluate(Hit()));

    [Fact]
    public void DamageModifierRangeAndSilentAimAreFlagged()
    {
        var dv = new DamageValidator(new DamageLimits());
        Assert.Contains(dv.Evaluate(Hit(damage: 120)), v => v.Code == "WPN_DMG_MODIFIER");
        Assert.Contains(dv.Evaluate(Hit(victimY: 400, at: T0.AddSeconds(5))), v => v.Code == "WPN_RANGE");
        Assert.Contains(dv.Evaluate(Hit(heading: 180, at: T0.AddSeconds(10))), v => v.Code == "WPN_AIM_ANGLE");
    }

    [Fact]
    public void RapidFireIsFlagged()
    {
        var dv = new DamageValidator(new DamageLimits());
        var found = new List<Violation>();
        for (int i = 0; i < 40; i++) found.AddRange(dv.Evaluate(Hit(at: T0.AddMilliseconds(i * 20))));
        Assert.Contains(found, v => v.Code == "WPN_RAPID_FIRE");
    }

    [Fact]
    public void HeadshotRatioIsFlagged()
    {
        var dv = new DamageValidator(new DamageLimits());
        var found = new List<Violation>();
        for (int i = 0; i < 25; i++) found.AddRange(dv.Evaluate(Hit(head: true, at: T0.AddSeconds(i))));
        Assert.Contains(found, v => v.Code == "WPN_HEADSHOT_RATIO");
    }

    [Fact]
    public void AbsorbedHitsAreFlagged()
    {
        var tracker = new AbsorbTracker { Threshold = 3 };
        for (int i = 0; i < 3; i++) tracker.RecordHit(5, 200, 0, T0.AddSeconds(i));
        var found = tracker.Process(T0.AddSeconds(10), _ => (200, 0, false, true), _ => false);
        Assert.Single(found);
        Assert.Equal("PLY_DAMAGE_ABSORB", found[0].Code);
    }

    [Fact]
    public void ExplosiveAmmoAndStealthExplosionsAreCancelled()
    {
        var ev = new ExplosionValidator(new ExplosionPolicy());
        var (v1, c1) = ev.Evaluate(new ExplosionInfo { Source = 1, ExplosionType = 18, DamageScale = 1, CameraShake = 1, At = T0 });
        Assert.True(c1);
        Assert.Contains(v1, v => v.Code == "WPN_EXPLOSIVE_AMMO");

        var (v2, c2) = ev.Evaluate(new ExplosionInfo { Source = 2, ExplosionType = 7, DamageScale = 1, IsInvisible = true, IsAudible = false, At = T0 });
        Assert.True(c2);

        var (v3, c3) = ev.Evaluate(new ExplosionInfo { Source = 3, ExplosionType = 7, DamageScale = 1, CameraShake = 1, At = T0 });
        Assert.False(c3);
        Assert.Empty(v3);
    }

    [Fact]
    public void BlacklistedVehicleAndSpawnFloodAreCancelled()
    {
        var cfg = AnticheatConfig.Parse("{}");
        var ent = new EntityValidator(cfg.Entities);
        var (v, cancel) = ent.Evaluate(4, Joaat.Hash("rhino"), EntityKind.Vehicle, true, T0);
        Assert.True(cancel);
        Assert.Contains(v, x => x.Code == "VEH_SPAWN");

        bool flooded = false;
        for (int i = 0; i < 20; i++)
            flooded |= ent.Evaluate(5, Joaat.Hash("prop_chair_01a"), EntityKind.Object, true, T0.AddMilliseconds(i * 100)).cancel;
        Assert.True(flooded);
    }

    [Fact]
    public void HealthRegenNeedsServerGrace()
    {
        var sv = new PlayerStateValidator();
        sv.Evaluate(6, 120, 0, false, T0);
        Assert.Contains(sv.Evaluate(6, 200, 0, false, T0.AddSeconds(1)), v => v.Code == "PLY_HEALTH_REGEN");
        sv.Evaluate(6, 120, 0, false, T0.AddSeconds(2));
        sv.GrantGrace(6, "heal", TimeSpan.FromSeconds(10), T0.AddSeconds(2));
        Assert.Empty(sv.Evaluate(6, 200, 0, false, T0.AddSeconds(3)));
    }

    [Fact]
    public void RateLimiterRefills()
    {
        long ticks = 0;
        var rl = new RateLimiter(() => ticks);
        var rule = new RateLimiter.Rule(5, 1);
        for (int i = 0; i < 5; i++) Assert.True(rl.TryConsume(1, "x", rule));
        Assert.False(rl.TryConsume(1, "x", rule));
        ticks += System.Diagnostics.Stopwatch.Frequency * 2;
        Assert.True(rl.TryConsume(1, "x", rule));
        Assert.True(rl.TryConsume(2, "x", rule));
    }

    [Fact]
    public void ClientOnlyEvidenceNeverBans()
    {
        var ledger = new ViolationLedger(new ScoringPolicy());
        Violation? last = null;
        for (int i = 0; i < 10; i++) { last = new Violation(1, "PLY_GODMODE_FLAG", ViolationSource.Client); ledger.Record(last, T0); }
        Assert.Equal(EnforcementAction.Kick, last!.Action);

        var server = new Violation(1, "MOV_TELEPORT", ViolationSource.Server);
        ledger.Record(server, T0);
        Assert.Equal(EnforcementAction.Ban, server.Action);
    }

    [Fact]
    public void ScoresDecay()
    {
        var ledger = new ViolationLedger(new ScoringPolicy { HalfLifeMinutes = 10 });
        ledger.Record(new Violation(1, "MOV_TELEPORT", ViolationSource.Server), T0);
        Assert.InRange(ledger.ScoreOf(1, T0.AddMinutes(10)), 19.9, 20.1);
    }

    [Fact]
    public void BanStoreMatchesAnyIdentifierAndPersists()
    {
        var path = Path.Combine(Path.GetTempPath(), "jac-bans-" + Guid.NewGuid() + ".json");
        try
        {
            var store = new BanStore(path);
            var ban = store.Add(new Ban { Name = "x", Identifiers = { "license:abc", "discord:1", "ip:1.2.3.4" }, Reason = "r" });
            Assert.NotNull(store.Find(new[] { "discord:1" }));
            Assert.Null(store.Find(new[] { "ip:1.2.3.4" }));

            var reloaded = new BanStore(path);
            Assert.Equal(ban.Id, reloaded.Find(new[] { "license:abc" })!.Id);
            Assert.True(reloaded.Remove(ban.Id));
            Assert.Null(reloaded.Find(new[] { "license:abc" }));
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public void JsonRoundTripsAndRejectsDeepNesting()
    {
        var src = "{\"a\":[1,2.5,\"x\\n\\u00e9\",true,null],\"b\":{\"c\":-3e2}}";
        var parsed = MiniJson.Parse(src);
        Assert.Equal(-300.0, parsed.Obj("b").Num("c"));
        Assert.Equal("x\né", (string?)((List<object?>)parsed.Arr("a")!)[2]);
        Assert.Equal(MiniJson.Serialize(parsed), MiniJson.Serialize(MiniJson.Parse(MiniJson.Serialize(parsed))));
        Assert.False(MiniJson.TryParse(new string('[', 100) + new string(']', 100), out _));
    }

    [Fact]
    public void ConfigOverridesApply()
    {
        var cfg = AnticheatConfig.Parse("{\"dryRun\":true,\"scoring\":{\"banAt\":300,\"severity\":{\"MOV_TELEPORT\":5}},\"weaponBlacklist\":[\"WEAPON_RPG\"]}");
        Assert.True(cfg.DryRun);
        Assert.Equal(300, cfg.Scoring.BanAt);
        Assert.Equal(5, new ViolationLedger(cfg.Scoring).SeverityOf("MOV_TELEPORT"));
        Assert.Equal(new[] { "WEAPON_RPG" }, cfg.WeaponBlacklist);
    }
}

public class IterationTwoTests
{
    private static readonly DateTime T0 = new(2026, 11, 5, 12, 0, 0, DateTimeKind.Utc);

    private static WeaponHit Hit(Vec3? impact, float heading = 0) => new()
    {
        Attacker = 1, VictimPlayer = 2, WeaponHash = Joaat.Hash("WEAPON_CARBINERIFLE"), Damage = 30,
        AttackerPos = new Vec3(0, 0, 0), AttackerHeading = heading, VictimPos = new Vec3(0, 40, 0), ImpactDir = impact, At = T0,
    };

    [Fact]
    public void TrajectoryAlongLineOfFireIsAcceptedInEitherSign()
    {
        var dv = new DamageValidator(new DamageLimits());
        Assert.DoesNotContain(dv.Evaluate(Hit(new Vec3(0.05f, 1, -0.02f))), v => v.Code == "WPN_TRAJECTORY");
        Assert.DoesNotContain(new DamageValidator(new DamageLimits()).Evaluate(Hit(new Vec3(0, -1, 0))), v => v.Code == "WPN_TRAJECTORY");
    }

    [Fact]
    public void SidewaysBulletIsFlagged()
    {
        var found = new DamageValidator(new DamageLimits()).Evaluate(Hit(new Vec3(1, 0, 0)));
        Assert.Contains(found, v => v.Code == "WPN_TRAJECTORY");
    }

    [Fact]
    public void MissingImpactDirSkipsTheCheck()
        => Assert.DoesNotContain(new DamageValidator(new DamageLimits()).Evaluate(Hit(null)), v => v.Code == "WPN_TRAJECTORY");

    [Fact]
    public void HeartbeatFailureDropsButNeverBansAlone()
    {
        var ledger = new ViolationLedger(new ScoringPolicy());
        var v = new Violation(3, "HB_INVALID", ViolationSource.Heartbeat);
        ledger.Record(v, T0);
        Assert.Equal(EnforcementAction.Kick, v.Action);
        Assert.True(v.ScoreAfter < new ScoringPolicy().BanAt);
    }

    [Fact]
    public void DropImmediatelyIsConfigurable()
    {
        var cfg = AnticheatConfig.Parse("{\"scoring\":{\"dropImmediately\":[]},\"damage\":{\"maxTrajectoryAngle\":30},\"floodDeniedPer10s\":10}");
        var v = new Violation(3, "HB_INVALID", ViolationSource.Heartbeat);
        new ViolationLedger(cfg.Scoring).Record(v, T0);
        Assert.Equal(EnforcementAction.Screenshot, v.Action);
        Assert.Equal(30f, cfg.Damage.MaxTrajectoryAngle);
        Assert.Equal(10, cfg.FloodDeniedPer10s);
    }

    [Fact]
    public void IgnoreListParses()
    {
        var cfg = AnticheatConfig.Parse("{\"scoring\":{\"ignore\":[\"VEH_HANDLING\",\"PLY_STAMINA\"]}}");
        Assert.Contains("VEH_HANDLING", cfg.Scoring.Ignore);
        Assert.Contains("PLY_STAMINA", cfg.Scoring.Ignore);
        Assert.Empty(AnticheatConfig.Parse("{}").Scoring.Ignore);
    }
}

public class StateConsistencyTests
{
    private static readonly Vec3 Here = new(100, 200, 30);

    [Fact]
    public void MatchingStateNeverReports()
    {
        var sc = new StateConsistencyValidator();
        for (int i = 0; i < 10; i++) Assert.Null(sc.Evaluate(1, 200, 50, Here, 195, 50, new Vec3(103, 200, 30), 2, false));
    }

    [Fact]
    public void HookedHealthIsReportedAfterAStreak()
    {
        var sc = new StateConsistencyValidator();
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false));
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false));
        var v = sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false);
        Assert.Equal("HB_STATE_MISMATCH", v!.Code);
    }

    [Fact]
    public void OneLaggyHeartbeatResetsTheStreak()
    {
        var sc = new StateConsistencyValidator();
        sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false);
        sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false);
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 200, 0, Here, 0, false));
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false));
    }

    [Fact]
    public void FastVehiclesGetPositionTolerance()
    {
        var sc = new StateConsistencyValidator();
        var server = new Vec3(160, 200, 30);
        for (int i = 0; i < 5; i++) Assert.Null(sc.Evaluate(1, 200, 0, Here, 200, 0, server, 50, false));
        var spoofed = new Vec3(2000, 200, 30);
        Violation? v = null;
        for (int i = 0; i < 3; i++) v = sc.Evaluate(2, 200, 0, Here, 200, 0, spoofed, 0, false);
        Assert.NotNull(v);
    }

    [Fact]
    public void GraceSkipsAndResets()
    {
        var sc = new StateConsistencyValidator();
        sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false);
        sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false);
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, true));
        Assert.Null(sc.Evaluate(1, 200, 0, Here, 120, 0, Here, 0, false));
    }
}

public class LedgerPersistenceTests
{
    private static readonly DateTime T0 = new(2026, 11, 5, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void ReconnectingDoesNotResetTheScore()
    {
        var ledger = new ViolationLedger(new ScoringPolicy { HalfLifeMinutes = 10 });
        ledger.Record(new Violation(7, "MOV_TELEPORT", ViolationSource.Server), T0);
        ledger.Record(new Violation(7, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server), T0);

        ledger.Park(7, "license:abc", T0);
        Assert.Equal(0, ledger.ScoreOf(7, T0));

        ledger.Restore(12, "license:abc", T0.AddMinutes(1));
        Assert.InRange(ledger.ScoreOf(12, T0.AddMinutes(1)), 80, 90);

        ledger.Record(new Violation(12, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server), T0.AddMinutes(1));
        var v = new Violation(12, "MOV_TELEPORT", ViolationSource.Server);
        ledger.Record(v, T0.AddMinutes(1));
        Assert.Equal(EnforcementAction.Ban, v.Action);

        var fresh = new ViolationLedger(new ScoringPolicy { HalfLifeMinutes = 10 });
        fresh.Record(new Violation(20, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server), T0);
        var f = new Violation(20, "MOV_TELEPORT", ViolationSource.Server);
        fresh.Record(f, T0);
        Assert.Equal(EnforcementAction.Kick, f.Action);
    }

    [Fact]
    public void FullyDecayedScoresAreNotKept()
    {
        var ledger = new ViolationLedger(new ScoringPolicy { HalfLifeMinutes = 10 });
        ledger.Record(new Violation(1, "PLY_STAMINA", ViolationSource.Client), T0);
        ledger.Park(1, "license:x", T0.AddHours(2));
        Assert.Equal(0, ledger.ParkedCount);
    }

    [Fact]
    public void RestoreWithoutParkedScoreIsANoop()
    {
        var ledger = new ViolationLedger(new ScoringPolicy());
        ledger.Restore(3, "license:none", T0);
        ledger.Restore(3, null, T0);
        Assert.Equal(0, ledger.ScoreOf(3, T0));
    }
}

public class LiveSettingsTests
{
    private static string ShippedConfig()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "resource", "jcks_anticheat", "config.json"))) dir = dir.Parent;
        return File.ReadAllText(Path.Combine(dir!.FullName, "resource", "jcks_anticheat", "config.json"));
    }

    [Fact]
    public void ShippedConfigIsValid() => Assert.Empty(AnticheatConfig.Parse(ShippedConfig()).Validate());

    [Fact]
    public void SerialisationRoundTrips()
    {
        var cfg = AnticheatConfig.Parse(ShippedConfig());
        cfg.Scoring.SeverityOverrides["MOV_TELEPORT"] = 55;
        cfg.Scoring.Ignore.Add("VEH_HANDLING");
        cfg.Entities.AllowedPedModelNames = new List<string> { "mp_m_freemode_01" };
        var again = AnticheatConfig.Parse(cfg.ToPrettyJson());
        Assert.Equal(MiniJson.Serialize(cfg.ToJson()), MiniJson.Serialize(again.ToJson()));
        Assert.Contains(Joaat.Hash("rhino"), again.Entities.BlacklistedModels);
    }

    [Fact]
    public void CopyFromUpdatesNestedObjectsInPlace()
    {
        var live = AnticheatConfig.Parse("{}");
        var scoringRef = live.Scoring;
        var movementRef = live.Movement;
        var ledger = new ViolationLedger(live.Scoring);

        var edited = AnticheatConfig.Parse("{\"dryRun\":true,\"scoring\":{\"kickAt\":60,\"banAt\":90},\"movement\":{\"onFootMaxSpeed\":20}}");
        live.CopyFrom(edited);

        Assert.Same(scoringRef, live.Scoring);
        Assert.Same(movementRef, live.Movement);
        Assert.True(live.DryRun);
        Assert.Equal(20f, movementRef.OnFootMaxSpeed);
        var v = new Violation(1, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server);
        ledger.Record(v, DateTime.UtcNow);
        ledger.Record(v = new Violation(1, "WPN_EXPLOSIVE_AMMO", ViolationSource.Server), DateTime.UtcNow);
        Assert.Equal(EnforcementAction.Ban, v.Action);
    }

    [Fact]
    public void InvalidConfigIsRejectedWithReasons()
    {
        var ex = Assert.Throws<FormatException>(() => AnticheatConfig.ParseValidated("{\"scoring\":{\"kickAt\":200,\"banAt\":100}}"));
        Assert.Contains("kickAt must be below", ex.Message);
        Assert.Throws<FormatException>(() => AnticheatConfig.ParseValidated("{not json"));
    }
}

public class GameEventTests
{
    private static readonly DateTime T0 = new(2026, 11, 5, 12, 0, 0, DateTimeKind.Utc);
    private static GameEventValidator V() => new(new GameEventPolicy(), () => new HashSet<uint> { Joaat.Hash("WEAPON_RPG") });

    [Fact]
    public void NormalShotPasses()
    {
        var (v, cancel) = V().Projectile(new ProjectileInfo { Source = 1, WeaponHash = Joaat.Hash("WEAPON_GRENADE"), Origin = new Vec3(1, 1, 1), ShooterPos = new Vec3(0, 0, 0), At = T0 });
        Assert.Empty(v);
        Assert.False(cancel);
    }

    [Fact]
    public void ProjectileSpawnedAtAnotherPlayerIsCancelled()
    {
        var (v, cancel) = V().Projectile(new ProjectileInfo { Source = 1, WeaponHash = Joaat.Hash("WEAPON_GRENADE"), Origin = new Vec3(300, 0, 0), ShooterPos = new Vec3(0, 0, 0), At = T0 });
        Assert.True(cancel);
        Assert.Contains(v, x => x.Code == "WPN_PROJECTILE_ORIGIN");
    }

    [Fact]
    public void VehicleWeaponsMayStartAwayFromThePed()
        => Assert.Empty(V().Projectile(new ProjectileInfo { Source = 1, Origin = new Vec3(30, 0, 0), ShooterPos = new Vec3(0, 0, 0), ShooterInVehicle = true, At = T0 }).violations);

    [Fact]
    public void BlacklistedProjectileAndSpamAreFlagged()
    {
        var val = V();
        Assert.Contains(val.Projectile(new ProjectileInfo { Source = 2, WeaponHash = Joaat.Hash("WEAPON_RPG"), At = T0 }).violations, x => x.Code == "WPN_BLACKLIST");
        var all = new List<Violation>();
        for (int i = 0; i < 25; i++) all.AddRange(val.Projectile(new ProjectileInfo { Source = 3, At = T0.AddMilliseconds(i * 100) }).violations);
        Assert.Contains(all, x => x.Code == "WPN_PROJECTILE_SPAM");
    }

    [Fact]
    public void FireOnAnotherPlayerAndFireSpam()
    {
        var val = V();
        Assert.Contains(val.Fire(new FireInfo { Source = 1, TargetPlayer = 2, At = T0 }).violations, x => x.Code == "WPN_FIRE_PLAYER");
        Assert.Empty(val.Fire(new FireInfo { Source = 4, TargetPlayer = 4, At = T0 }).violations);
        Assert.Contains(val.Fire(new FireInfo { Source = 5, Count = 12, At = T0 }).violations, x => x.Code == "WPN_FIRE_SPAM");
    }

    [Fact]
    public void PtfxScaleTargetAndSpam()
    {
        var val = V();
        Assert.Empty(val.Ptfx(new PtfxInfo { Source = 1, Scale = 1, At = T0 }).violations);
        Assert.NotEmpty(val.Ptfx(new PtfxInfo { Source = 1, Scale = 50, At = T0 }).violations);
        Assert.NotEmpty(val.Ptfx(new PtfxInfo { Source = 1, Scale = 1, TargetPlayer = 9, At = T0 }).violations);
        var all = new List<Violation>();
        for (int i = 0; i < 45; i++) all.AddRange(val.Ptfx(new PtfxInfo { Source = 6, Scale = 1, At = T0 }).violations);
        Assert.NotEmpty(all);
    }
}

public class VehicleOwnershipTests
{
    [Fact]
    public void DriverOfSomeoneElsesLockedCarIsFlaggedOnce()
    {
        var v = new VehicleOwnership();
        v.Track(100, creatorPlayer: 1);
        Assert.Null(v.CheckDriver(1, 100, 2, true, false));
        Assert.Null(v.CheckDriver(2, 100, 1, true, false));
        Assert.Null(v.CheckDriver(2, 100, 2, true, true));
        Assert.Null(v.CheckDriver(2, 100, 2, false, false));
        Assert.Equal("VEH_HIJACK", v.CheckDriver(2, 100, 2, true, false)!.Code);
        Assert.Null(v.CheckDriver(2, 100, 2, true, false));
    }

    [Fact]
    public void UntrackedAndRemovedVehiclesAreIgnored()
    {
        var v = new VehicleOwnership();
        Assert.Null(v.CheckDriver(2, 5, 2, true, false));
        v.Track(6, 1);
        v.Untrack(6);
        Assert.Null(v.CheckDriver(2, 6, 2, true, false));
        v.Track(7, 1);
        v.ForgetPlayer(1);
        Assert.Equal(0, v.CreatorOf(7));
    }
}

public class ExplosionBlameTests
{
    [Fact]
    public void ExplosionOwnedByAnotherPlayerIsCancelled()
    {
        var ev = new ExplosionValidator(new ExplosionPolicy());
        var (v, cancel) = ev.Evaluate(new ExplosionInfo { Source = 1, ExplosionType = 2, DamageScale = 1, CameraShake = 1, OwnerPlayer = 7 });
        Assert.True(cancel);
        Assert.Contains(v, x => x.Code == "WPN_EXPLOSION_BLAME");
    }

    [Fact]
    public void OwnExplosionIsFine()
    {
        var ev = new ExplosionValidator(new ExplosionPolicy());
        Assert.Empty(ev.Evaluate(new ExplosionInfo { Source = 3, ExplosionType = 2, DamageScale = 1, CameraShake = 1, OwnerPlayer = 3 }).violations);
        Assert.Empty(ev.Evaluate(new ExplosionInfo { Source = 4, ExplosionType = 7, DamageScale = 1, CameraShake = 1, OwnerPlayer = 0 }).violations);
    }

    [Fact]
    public void DestroyedVehicleExplosionCreditingTheAttackerIsNotBlame()
        => Assert.Empty(new ExplosionValidator(new ExplosionPolicy()).Evaluate(
            new ExplosionInfo { Source = 8, ExplosionType = 7, DamageScale = 1, CameraShake = 1, OwnerPlayer = 9 }).violations);
}

public class ProtectedEventConfigTests
{
    [Fact]
    public void ProtectedEventsParseRoundTripAndValidate()
    {
        var cfg = AnticheatConfig.Parse("{\"protectedEvents\":{\"esx_jobs:pay\":10,\"qb-bank:server:deposit\":30}}");
        Assert.Equal(10, cfg.ProtectedEvents["esx_jobs:pay"]);
        var again = AnticheatConfig.Parse(cfg.ToPrettyJson());
        Assert.Equal(30, again.ProtectedEvents["qb-bank:server:deposit"]);
        Assert.Empty(again.Validate());
        Assert.Throws<FormatException>(() => AnticheatConfig.ParseValidated("{\"protectedEvents\":{\"x\":0}}"));
        Assert.Throws<FormatException>(() => AnticheatConfig.ParseValidated("{\"scoring\":{\"severity\":{\"bad code\":5}}}"));
    }
}

public class MassTeleportTests
{
    private static Violation Tp(int p) => new(p, "MOV_TELEPORT", ViolationSource.Server);

    [Fact]
    public void VictimsOfBringAllAreSparedAndThePullerIsReported()
    {
        var spot = new Vec3(500, 500, 30);
        var teleports = new List<(int, Violation, Vec3)>
        {
            (2, Tp(2), new Vec3(502, 500, 30)), (3, Tp(3), new Vec3(498, 503, 30)), (4, Tp(4), new Vec3(501, 497, 30)),
        };
        var everyone = new List<(int, Vec3)> { (1, spot), (2, new Vec3(502, 500, 30)), (3, new Vec3(498, 503, 30)), (4, new Vec3(501, 497, 30)), (9, new Vec3(-2000, 0, 0)) };
        var result = MassTeleportDetector.Process(teleports, everyone);
        var v = Assert.Single(result);
        Assert.Equal("MOV_BRING_ALL", v.Code);
        Assert.Equal(1, v.Player);
    }

    [Fact]
    public void ScatteredTeleportsStayIndividual()
    {
        var teleports = new List<(int, Violation, Vec3)>
        {
            (2, Tp(2), new Vec3(0, 0, 0)), (3, Tp(3), new Vec3(1000, 0, 0)), (4, Tp(4), new Vec3(0, 1000, 0)),
        };
        var result = MassTeleportDetector.Process(teleports, new List<(int, Vec3)>());
        Assert.Equal(3, result.Count);
        Assert.All(result, v => Assert.Equal("MOV_TELEPORT", v.Code));
    }

    [Fact]
    public void TwoPlayersTogetherAreNotAMassTeleport()
    {
        var teleports = new List<(int, Violation, Vec3)> { (2, Tp(2), new Vec3(0, 0, 0)), (3, Tp(3), new Vec3(3, 0, 0)) };
        Assert.Equal(2, MassTeleportDetector.Process(teleports, new List<(int, Vec3)>()).Count);
    }
}

public class NameFilterTests
{
    [Theory]
    [InlineData("<img src=x onerror=alert(1)>", true)]
    [InlineData("Tony <b>Boss</b>", true)]
    [InlineData("<script>", true)]
    [InlineData("Marcus Vane", false)]
    [InlineData("x < y > z", false)]
    [InlineData("~r~Red Name", false)]
    public void HtmlNamesAreRefused(string name, bool refused)
        => Assert.Equal(refused, NameFilter.Check(name, true, Array.Empty<string>()) != null);

    [Fact]
    public void BlacklistIsCaseInsensitive()
    {
        Assert.NotNull(NameFilter.Check("xX_ModMenu_Xx", true, new[] { "modmenu" }));
        Assert.Null(NameFilter.Check("Tony", true, new[] { "modmenu" }));
        Assert.NotNull(NameFilter.Check("  ", true, Array.Empty<string>()));
    }
}

public class AlwaysBanTests
{
    [Fact]
    public void AlwaysBanCodesBanOnFirstServerDetection()
    {
        var ledger = new ViolationLedger(new ScoringPolicy { AlwaysBan = { "NET_HONEYPOT" } });
        var v = new Violation(1, "NET_HONEYPOT", ViolationSource.Server);
        ledger.Record(v, DateTime.UtcNow);
        Assert.Equal(EnforcementAction.Ban, v.Action);
        var c = AnticheatConfig.Parse("{\"scoring\":{\"alwaysBan\":[\"WPN_EXPLOSION_BLAME\"]}}");
        Assert.Contains("WPN_EXPLOSION_BLAME", AnticheatConfig.Parse(c.ToPrettyJson()).Scoring.AlwaysBan);
    }
}
