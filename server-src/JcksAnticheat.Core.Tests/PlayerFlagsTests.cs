using System.Linq;
using JcksAnticheat.Core.Detection;
using JcksAnticheat.Core.Validation;
using Xunit;

public class PlayerFlagsTests
{
    private static PlayerFlags Clean(bool superJump = false, float dmg = 1f, float melee = 1f, float def = 1f, float def2 = 1f, int maxHealth = 200,
        bool noCollision = false, bool attached = false, bool inVehicle = false, bool dead = false)
        => new PlayerFlags(superJump, dmg, melee, def, def2, maxHealth, noCollision, attached, inVehicle, dead);

    [Fact]
    public void CleanPlayerProducesNothing()
    {
        var v = new PlayerFlagsValidator();
        for (int i = 0; i < 10; i++) Assert.Empty(v.Evaluate(1, Clean()));
    }

    [Fact]
    public void SyncFlagsAreReported()
    {
        var v = new PlayerFlagsValidator();
        var codes = v.Evaluate(1, Clean(superJump: true, dmg: 3f, def: 0.1f, maxHealth: 1000)).Select(x => x.Code).ToList();
        Assert.Contains("PLY_SUPERJUMP", codes);
        Assert.Contains("WPN_DMG_MODIFIER", codes);
        Assert.Contains("PLY_GODMODE_PROOFS", codes);
        Assert.Contains("PLY_HEALTH_CAP", codes);
        Assert.All(v.Evaluate(2, Clean(melee: 5f)), x => Assert.Equal(ViolationSource.Server, x.Source));
    }

    [Fact]
    public void ServerWideDamageModifierIsRespected()
    {
        var v = new PlayerFlagsValidator { ExpectedDamageModifier = 0.5 };
        Assert.Empty(v.Evaluate(1, Clean(dmg: 0.5f, melee: 0.5f)));
        Assert.Single(v.Evaluate(1, Clean(dmg: 1f, melee: 0.5f)), x => x.Code == "WPN_DMG_MODIFIER");
    }

    [Fact]
    public void CollisionNeedsAStreakAndIgnoresAttachedOrSeated()
    {
        var v = new PlayerFlagsValidator { CollisionStreak = 3 };
        Assert.Empty(v.Evaluate(1, Clean(noCollision: true)));
        Assert.Empty(v.Evaluate(1, Clean(noCollision: true)));
        Assert.Single(v.Evaluate(1, Clean(noCollision: true)), x => x.Code == "MOV_NOCLIP_COLLISION");

        for (int i = 0; i < 5; i++)
        {
            Assert.Empty(v.Evaluate(2, Clean(noCollision: true, attached: true)));
            Assert.Empty(v.Evaluate(3, Clean(noCollision: true, inVehicle: true)));
        }
        v.Evaluate(4, Clean(noCollision: true));
        v.Evaluate(4, Clean(noCollision: true));
        v.Evaluate(4, Clean());
        Assert.Empty(v.Evaluate(4, Clean(noCollision: true)));
    }

    [Fact]
    public void DeadPlayersAreSkipped()
    {
        Assert.Empty(new PlayerFlagsValidator().Evaluate(1, Clean(superJump: true, dmg: 9f, dead: true)));
    }

    [Fact]
    public void AttachmentsToOthersAboveLimitAreFlaggedAndRemoved()
    {
        var list = new[]
        {
            new Attachment(100, 5, 7), new Attachment(101, 5, 8), new Attachment(102, 5, 7),
            new Attachment(200, 6, 6), new Attachment(201, 6, 6), new Attachment(202, 6, 6),
            new Attachment(300, 9, 7),
            new Attachment(400, -1, 7), new Attachment(401, -1, 7), new Attachment(402, -1, 7),
        };
        var (violations, remove) = AttachmentWatch.Evaluate(list, 2);
        var only = Assert.Single(violations);
        Assert.Equal(5, only.Player);
        Assert.Equal("ENT_ATTACH_PLAYER", only.Code);
        Assert.Equal(new[] { 100, 101, 102 }, remove.OrderBy(x => x));
        Assert.Empty(AttachmentWatch.Evaluate(list, 3).violations);
    }

    [Fact]
    public void NewGraceKindsMapToTrustedBehaviours()
    {
        Assert.Equal("superjump", GraceDeferral.KindFor("PLY_SUPERJUMP"));
        Assert.Equal("noclip", GraceDeferral.KindFor("MOV_NOCLIP_COLLISION"));
        Assert.Equal("weapons", GraceDeferral.KindFor("WPN_DMG_MODIFIER"));
        Assert.Equal("godmode", GraceDeferral.KindFor("PLY_GODMODE_PROOFS"));
        Assert.True(JcksAnticheat.Core.Config.Behaviours.IsKnown("superjump"));
    }
}

public class EntityScriptCheckTests
{
    [Fact]
    public void ScriptEntityFromUnknownResourceIsReported()
    {
        var v = EntityScriptCheck.Evaluate(5, true, false, null, 123u, EntityKind.Vehicle);
        Assert.NotNull(v);
        Assert.Equal("ENT_UNKNOWN_SCRIPT", v!.Code);
        Assert.Equal(5, v.Player);
    }

    [Fact]
    public void KnownResourcesPopulationAndPlayerPedsAreIgnored()
    {
        Assert.Null(EntityScriptCheck.Evaluate(5, true, false, "qb-garages", 1u, EntityKind.Vehicle));
        Assert.Null(EntityScriptCheck.Evaluate(5, false, false, null, 1u, EntityKind.Ped));
        Assert.Null(EntityScriptCheck.Evaluate(5, true, true, null, 1u, EntityKind.Ped));
        Assert.Null(EntityScriptCheck.Evaluate(0, true, false, null, 1u, EntityKind.Object));
    }

    [Fact]
    public void UnknownScriptIsLogOnlyByDefault()
    {
        Assert.Contains("ENT_UNKNOWN_SCRIPT", new ScoringPolicy().LogOnly);
        Assert.Contains("ENT_UNKNOWN_SCRIPT", JcksAnticheat.Core.Config.AnticheatConfig.Parse("{}").Scoring.LogOnly);
    }
}
