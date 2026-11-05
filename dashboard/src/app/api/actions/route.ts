import { NextResponse } from "next/server";
import { actorName } from "@/lib/auth";
import { badRequest, withSession } from "@/lib/http";
import { isServerConnected } from "@/lib/servers";
import { store } from "@/lib/store";
import type { CommandType } from "@/lib/types";

const TYPES = new Set<CommandType>(["ban", "unban", "kick", "screenshot"]);
const NEEDS_MOD = new Set<CommandType>(["ban", "unban"]);

export const POST = withSession(async (session, req) => {
  const body = (await req.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) return badRequest("invalid json");
  const type = body.type as CommandType;
  if (!TYPES.has(type)) return badRequest("unknown action");
  if (NEEDS_MOD.has(type) && session.role === "Support") {
    return NextResponse.json({ error: "Your role can't ban or unban." }, { status: 403 });
  }

  const serverId = typeof body.serverId === "string" ? body.serverId : "main";
  const player = typeof body.player === "number" ? body.player : undefined;
  const banId = typeof body.banId === "string" ? body.banId : undefined;
  const reason = typeof body.reason === "string" ? body.reason.slice(0, 200) : undefined;
  const durationHours = typeof body.durationHours === "number" && body.durationHours > 0 ? body.durationHours : undefined;

  if (type === "unban" ? !banId : player === undefined) return badRequest(type === "unban" ? "banId required" : "player required");
  if (type === "ban" && !reason) return badRequest("reason required");

  const actor = actorName(session);
  const known = player !== undefined ? store.player(`${serverId}:${player}`) : null;
  const cmd = store.queueCommand({
    serverId, type, player, banId, reason, durationHours, actor,
    ...(type === "ban" && known ? { identifiers: known.identifiers, name: known.name } : {}),
  });
  if (type === "unban" && banId) store.markPendingUnban(banId);

  if (store.demo && !isServerConnected(serverId)) simulate(serverId, cmd.type, { player, banId, reason, durationHours, actor });

  return NextResponse.json({ ok: true, command: cmd, delivered: isServerConnected(serverId) ? "queued" : store.demo ? "simulated" : "queued-offline" });
});

function simulate(serverId: string, type: CommandType, c: { player?: number; banId?: string; reason?: string; durationHours?: number; actor: string }) {
  setTimeout(() => {
    store.takeCommands(serverId);
    const p = c.player !== undefined ? store.player(`${serverId}:${c.player}`) : null;
    if (type === "unban" && c.banId) store.removeBan(c.banId, c.actor);
    if ((type === "kick" || type === "ban") && p) store.setOffline(serverId, p.id);
    if (type === "ban" && p) {
      store.addBan({
        id: crypto.randomUUID().replace(/-/g, "").slice(0, 12),
        name: p.name,
        identifiers: p.identifiers,
        reason: c.reason ?? "Banned by staff",
        code: "MANUAL",
        bannedBy: c.actor,
        createdAt: new Date().toISOString(),
        expiresAt: c.durationHours ? new Date(Date.now() + c.durationHours * 3_600_000).toISOString() : null,
      });
    }
    if (type === "kick" && p) store.pushLog({ level: "warn", kind: "kick", text: `KICK ${p.name} (#${p.id}) by ${c.actor}: ${c.reason ?? "no reason"}` });
    if (type === "screenshot" && p) store.pushLog({ level: "info", kind: "screenshot", text: `screenshot requested for ${p.name} (#${p.id}) (demo: no game client to capture)` });
  }, 800);
}
