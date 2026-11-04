import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { exchangeCode, SESSION_COOKIE, signSession, STATE_COOKIE } from "@/lib/auth";
import { store } from "@/lib/store";

/** Step 2: verify state, exchange the code, set the session cookie. */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const jar = await cookies();
  const expected = jar.get(STATE_COOKIE)?.value;
  const state = url.searchParams.get("state");
  if (!expected || !state || state !== expected) {
    return NextResponse.redirect(new URL("/login?error=invalid_state", req.url));
  }

  const user = exchangeCode(url.searchParams.get("code") ?? "");
  if (!user) return NextResponse.redirect(new URL("/login?error=invalid_code", req.url));

  const res = NextResponse.redirect(new URL("/live", req.url));
  res.cookies.delete(STATE_COOKIE);
  res.cookies.set(SESSION_COOKIE, signSession(user), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 12,
  });
  store.pushLog({ level: "info", kind: "auth", text: `${user.username} signed in (${user.role})` });
  return res;
}
