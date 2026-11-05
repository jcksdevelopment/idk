import "server-only";
import { NextResponse } from "next/server";
import { sessionFromRequest } from "./auth";
import type { Session } from "./types";

export const unauthorized = () => NextResponse.json({ error: "unauthorized" }, { status: 401 });
export const badRequest = (msg: string) => NextResponse.json({ error: msg }, { status: 400 });

export function withSession<A extends unknown[]>(fn: (session: Session, req: Request, ...rest: A) => Promise<Response> | Response) {
  return async (req: Request, ...rest: A) => {
    const s = await sessionFromRequest();
    if (!s) return unauthorized();
    return fn(s, req, ...rest);
  };
}

export function intParam(url: URL, key: string, fallback: number) {
  const n = Number.parseInt(url.searchParams.get(key) ?? "", 10);
  return Number.isFinite(n) ? n : fallback;
}
