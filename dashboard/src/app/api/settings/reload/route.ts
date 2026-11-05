import { NextResponse } from "next/server";
import { actorName, canEditSettings } from "@/lib/auth";
import { withSession } from "@/lib/http";
import { store } from "@/lib/store";

export const POST = withSession(async (session, req) => {
  if (!canEditSettings(session.role)) return NextResponse.json({ error: "Only Head Admins can reload settings." }, { status: 403 });
  const body = (await req.json().catch(() => ({}))) as { serverId?: string };
  const serverId = typeof body.serverId === "string" ? body.serverId : "main";
  store.queueCommand({ serverId, type: "reload", actor: actorName(session) });
  return NextResponse.json({ ok: true });
});
