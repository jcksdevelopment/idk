import { NextResponse } from "next/server";
import { withSession } from "@/lib/http";
import { store } from "@/lib/store";

export const GET = withSession(async (_s, req) => {
  const f = new URL(req.url).searchParams.get("filter");
  return NextResponse.json({ items: store.vision(f === "pending" || f === "cheat" ? f : "all") });
});
