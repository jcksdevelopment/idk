import { randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { STATE_COOKIE } from "@/lib/auth";

/** Step 1: create a CSRF state and "redirect to Discord" (our mock consent page). */
export async function GET(req: Request) {
  const state = randomBytes(16).toString("hex");
  const url = new URL("/login/authorize", req.url);
  url.searchParams.set("client_id", "jcks_anticheat");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", "identify guilds.members.read");
  url.searchParams.set("state", state);
  const res = NextResponse.redirect(url);
  res.cookies.set(STATE_COOKIE, state, { httpOnly: true, sameSite: "lax", secure: process.env.NODE_ENV === "production", path: "/", maxAge: 600 });
  return res;
}
