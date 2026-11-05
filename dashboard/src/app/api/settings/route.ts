import { NextResponse } from "next/server";
import { actorName, canEditSettings } from "@/lib/auth";
import { badRequest, withSession } from "@/lib/http";
import { isServerConnected } from "@/lib/servers";
import { store } from "@/lib/store";

export const GET = withSession(async (session, req) => {
  const serverId = new URL(req.url).searchParams.get("serverId") ?? "main";
  return NextResponse.json({
    settings: store.settings(serverId),
    connected: isServerConnected(serverId),
    demo: store.demo,
    canEdit: canEditSettings(session.role),
  });
});

export const POST = withSession(async (session, req) => {
  if (!canEditSettings(session.role)) return NextResponse.json({ error: "Only Head Admins can change settings." }, { status: 403 });
  const body = (await req.json().catch(() => null)) as { serverId?: string; config?: unknown } | null;
  if (!body || !body.config || typeof body.config !== "object" || Array.isArray(body.config)) return badRequest("config object required");
  const serverId = typeof body.serverId === "string" ? body.serverId : "main";
  const config = JSON.stringify(body.config);
  if (config.length > 256 * 1024) return badRequest("config too large");

  const actor = actorName(session);
  store.queueCommand({ serverId, type: "config", config, actor });
  store.markSettingsPending(serverId);

  if (store.demo && !isServerConnected(serverId)) {
    store.takeCommands(serverId);
    store.setSettings(serverId, body.config as Record<string, unknown>, null);
    store.pushLog({ level: "warn", kind: "settings", text: `settings saved by ${actor} (demo: no game server)` });
    return NextResponse.json({ ok: true, delivered: "simulated" });
  }
  return NextResponse.json({ ok: true, delivered: isServerConnected(serverId) ? "queued" : "queued-offline" });
});
