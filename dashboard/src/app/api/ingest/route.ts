import { NextResponse } from "next/server";
import { checkServerToken } from "@/lib/auth";
import { applyEvent } from "@/lib/ingest";
import { markServerSeen } from "@/lib/servers";
import { unauthorized, badRequest } from "@/lib/http";

/** Game server → dashboard event batches. Auth: Bearer SENTINEL_DASHBOARD_SECRET. */
export async function POST(req: Request) {
  if (!checkServerToken(req)) return unauthorized();
  let body: { serverId?: unknown; events?: unknown };
  try {
    body = await req.json();
  } catch {
    return badRequest("invalid json");
  }
  const serverId = typeof body.serverId === "string" && body.serverId ? body.serverId.slice(0, 32) : "main";
  const events = Array.isArray(body.events) ? body.events : [];
  markServerSeen(serverId);
  let applied = 0;
  for (const ev of events.slice(0, 1000)) {
    if (ev && typeof ev === "object") {
      applyEvent(serverId, ev as Record<string, unknown>);
      applied++;
    }
  }
  return NextResponse.json({ ok: true, applied });
}
