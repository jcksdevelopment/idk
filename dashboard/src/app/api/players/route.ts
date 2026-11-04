import { NextResponse } from "next/server";
import { intParam, withSession } from "@/lib/http";
import { store } from "@/lib/store";

export const GET = withSession(async (_s, req) => {
  const url = new URL(req.url);
  return NextResponse.json(
    store.players({
      q: url.searchParams.get("q") ?? undefined,
      page: intParam(url, "page", 1),
      pageSize: intParam(url, "pageSize", 20),
      status: url.searchParams.get("status") === "online" ? "online" : "all",
    }),
  );
});
