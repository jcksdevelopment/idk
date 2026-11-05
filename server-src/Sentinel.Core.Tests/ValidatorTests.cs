using Sentinel.Core.Bans;
using Sentinel.Core.Config;
using Sentinel.Core.Detection;
using Sentinel.Core.Json;
using Sentinel.Core.Validation;
using Xunit;

namespace Sentinel.Core.Tests;

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
        Assert.Empty(mv.Evaluate(1, new MovementSample(new Vec3(60, 0, 0), default, MovementMode.LandVehicle, T0.AddSeconds(1)))); // 216 km/h
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
        // Heading 180 faces -Y; the victim is at +Y, directly behind the shooter.
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
        var cfg = SentinelConfig.Parse("{}");
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
        Assert.True(rl.TryConsume(2, "x", rule)); // other players unaffected
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
        var path = Path.Combine(Path.GetTempPath(), "sentinel-bans-" + Guid.NewGuid() + ".json");
        try
        {
            var store = new BanStore(path);
            var ban = store.Add(new Ban { Name = "x", Identifiers = { "license:abc", "discord:1", "ip:1.2.3.4" }, Reason = "r" });
            Assert.NotNull(store.Find(new[] { "discord:1" }));
            Assert.Null(store.Find(new[] { "ip:1.2.3.4" })); // IPs never key bans

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
        var cfg = SentinelConfig.Parse("{\"dryRun\":true,\"scoring\":{\"banAt\":300,\"severity\":{\"MOV_TELEPORT\":5}},\"weaponBlacklist\":[\"WEAPON_RPG\"]}");
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
        var cfg = SentinelConfig.Parse("{\"scoring\":{\"dropImmediately\":[]},\"damage\":{\"maxTrajectoryAngle\":30},\"floodDeniedPer10s\":10}");
        var v = new Violation(3, "HB_INVALID", ViolationSource.Heartbeat);
        new ViolationLedger(cfg.Scoring).Record(v, T0);
        Assert.Equal(EnforcementAction.Screenshot, v.Action);
        Assert.Equal(30f, cfg.Damage.MaxTrajectoryAngle);
        Assert.Equal(10, cfg.FloodDeniedPer10s);
    }
}
