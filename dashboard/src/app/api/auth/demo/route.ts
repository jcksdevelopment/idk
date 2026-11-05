import { NextResponse } from "next/server";
import { demoProfile, SESSION_COOKIE, signSession } from "@/lib/auth";
import { store } from "@/lib/store";

export async function POST(req: Request) {
  const form = await req.formData().catch(() => null);
  const user = demoProfile(String(form?.get("profile") ?? ""));
  if (!user) return NextResponse.redirect(new URL("/login?error=profile", req.url), 303);
  const res = NextResponse.redirect(new URL("/overview", req.url), 303);
  res.cookies.set(SESSION_COOKIE, signSession(user), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production" && new URL(req.url).protocol === "https:",
    path: "/",
    maxAge: 60 * 60 * 12,
  });
  store.pushLog({ level: "info", kind: "auth", text: `${user.username} signed in (${user.role})` });
  return res;
}
