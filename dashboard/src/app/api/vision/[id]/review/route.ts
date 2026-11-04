import { NextResponse } from "next/server";
import { actorName, sessionFromRequest } from "@/lib/auth";
import { badRequest, unauthorized } from "@/lib/http";
import { store } from "@/lib/store";

export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await sessionFromRequest();
  if (!session) return unauthorized();
  const { id } = await params;
  const body = (await req.json().catch(() => null)) as { review?: string } | null;
  if (body?.review !== "confirmed" && body?.review !== "dismissed") return badRequest("review must be confirmed or dismissed");
  const capture = store.reviewVision(id, body.review, actorName(session));
  if (!capture) return NextResponse.json({ error: "not found" }, { status: 404 });
  store.pushLog({ level: "info", kind: "review", text: `vision ${id} marked ${body.review} by ${actorName(session)}` });
  return NextResponse.json({ ok: true, capture });
}
