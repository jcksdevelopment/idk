import { NextResponse } from "next/server";
import { checkServerToken } from "@/lib/auth";
import { unauthorized } from "@/lib/http";
import { markServerSeen } from "@/lib/servers";
import { store } from "@/lib/store";

/** Game server polls for moderator commands (ban/unban/kick/screenshot). */
export async function GET(req: Request) {
  if (!checkServerToken(req)) return unauthorized();
  const serverId = (new URL(req.url).searchParams.get("serverId") ?? "main").slice(0, 32);
  markServerSeen(serverId);
  return NextResponse.json({ commands: store.takeCommands(serverId) });
}
