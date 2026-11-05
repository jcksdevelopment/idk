import { NextResponse } from "next/server";
import { withSession } from "@/lib/http";
import { isServerConnected } from "@/lib/servers";
import { store } from "@/lib/store";

export const GET = withSession(async () => {
  const serverId = "main";
  const settings = store.settings(serverId);
  const cfg = (settings?.config ?? {}) as Record<string, unknown>;
  const cm = (cfg.countermeasures ?? {}) as Record<string, unknown>;
  const scoring = (cfg.scoring ?? {}) as Record<string, unknown>;
  const backdoors = store.backdoorScan(serverId);
  const integrations = store.integrationSuggestions(serverId);
  return NextResponse.json({
    stats: store.stats(),
    day: store.detectionStats(24, serverId),
    recent: store.detections({ limit: 8 }),
    bans: store.bans({ page: 1, pageSize: 5 }).items,
    top: store.players({ status: "online", page: 1, pageSize: 200 }).items.filter((p) => p.score > 0).sort((a, b) => b.score - a.score).slice(0, 5),
    server: {
      connected: isServerConnected(serverId),
      demo: store.demo,
      dryRun: cfg.dryRun === true,
      countermeasures: cm.enabled !== false,
      kickAt: typeof scoring.kickAt === "number" ? scoring.kickAt : null,
      banAt: typeof scoring.banAt === "number" ? scoring.banAt : null,
      settingsAt: settings?.updatedAt ?? null,
    },
    attention: {
      vision: store.stats().pendingReview,
      backdoorsHigh: backdoors?.findings.filter((f) => f.severity === "high").length ?? 0,
      backdoorsTotal: backdoors?.findings.length ?? 0,
      integrations: integrations?.suggestions.length ?? 0,
    },
  });
});
