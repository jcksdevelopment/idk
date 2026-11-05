import { NextResponse } from "next/server";
import { withSession } from "@/lib/http";
import { store } from "@/lib/store";

const RANGES = new Set([1, 24, 168, 720]);

export const GET = withSession(async (_s, req) => {
  const url = new URL(req.url);
  const hours = Number(url.searchParams.get("hours") ?? 24);
  return NextResponse.json(store.detectionStats(RANGES.has(hours) ? hours : 24, url.searchParams.get("serverId") ?? undefined));
});
