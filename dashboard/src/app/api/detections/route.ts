import { NextResponse } from "next/server";
import { intParam, withSession } from "@/lib/http";
import { store } from "@/lib/store";

export const GET = withSession(async (_s, req) => {
  const url = new URL(req.url);
  return NextResponse.json({
    items: store.detections({ player: url.searchParams.get("player") ?? undefined, limit: Math.min(intParam(url, "limit", 50), 500) }),
  });
});
