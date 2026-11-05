import { NextResponse } from "next/server";
import { actorName, canEditSettings } from "@/lib/auth";
import { badRequest, withSession } from "@/lib/http";
import { isServerConnected } from "@/lib/servers";
import { store } from "@/lib/store";

const ACTIONS = new Set(["apply", "clear"]);

export const GET = withSession(async (session, req) => {
  const serverId = new URL(req.url).searchParams.get("serverId") ?? "main";
  return NextResponse.json({ data: store.integrationSuggestions(serverId), connected: isServerConnected(serverId), canAct: canEditSettings(session.role) });
});

export const POST = withSession(async (session, req) => {
  if (!canEditSettings(session.role)) return NextResponse.json({ error: "Only Head Admins can change integrations." }, { status: 403 });
  const body = (await req.json().catch(() => null)) as { serverId?: string; action?: string } | null;
  const action = body?.action ?? "";
  if (!ACTIONS.has(action)) return badRequest("unknown action");
  const serverId = typeof body?.serverId === "string" ? body.serverId : "main";
  store.queueCommand({ serverId, type: "integrations", reason: action, actor: actorName(session) });
  return NextResponse.json({ ok: true, connected: isServerConnected(serverId) });
});
