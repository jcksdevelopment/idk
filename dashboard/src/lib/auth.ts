import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import type { Session } from "./types";

/**
 * Mock Discord OAuth2. The flow and cookie shape match a real integration, so swapping in real
 * Discord means replacing `exchangeCode` with a token exchange + /users/@me + guild role check.
 *
 *   /login → /api/auth/discord (authorize redirect) → /login/authorize (mock consent screen)
 *          → /api/auth/callback?code=…&state=… → signed session cookie → /live
 */

export const SESSION_COOKIE = "sentinel_session";
export const STATE_COOKIE = "sentinel_oauth_state";
const SESSION_TTL_SECONDS = 60 * 60 * 12;

function secret(): string {
  const s = process.env.SESSION_SECRET;
  if (s && s.length >= 32) return s;
  if (process.env.NODE_ENV === "production" && process.env.SENTINEL_DEMO === "0") {
    throw new Error("SESSION_SECRET (32+ chars) is required in production");
  }
  return "sentinel-dev-session-secret-change-me-please";
}

/** Staff accounts the mock consent screen offers. Real Discord would decide this from guild roles. */
export const MOCK_DISCORD_USERS = [
  { id: "184405311681986560", username: "Mara", role: "Head Admin", avatar: "M" },
  { id: "300293746132516865", username: "Theo", role: "Moderator", avatar: "T" },
  { id: "412378945612332032", username: "Kai", role: "Support", avatar: "K" },
] as const;

const b64url = (buf: Buffer | string) => Buffer.from(buf).toString("base64url");

export function signSession(s: Omit<Session, "exp">): string {
  const payload: Session = { ...s, exp: Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS };
  const body = b64url(JSON.stringify(payload));
  const mac = createHmac("sha256", secret()).update(body).digest("base64url");
  return `${body}.${mac}`;
}

export function verifySession(token: string | undefined): Session | null {
  if (!token) return null;
  const [body, mac] = token.split(".");
  if (!body || !mac) return null;
  const expected = createHmac("sha256", secret()).update(body).digest();
  const given = Buffer.from(mac, "base64url");
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null;
  try {
    const s = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as Session;
    return s.exp > Date.now() / 1000 ? s : null;
  } catch {
    return null;
  }
}

/** Mock code exchange: the code is "mock_<discord id>". */
export function exchangeCode(code: string): Omit<Session, "exp"> | null {
  const id = code.startsWith("mock_") ? code.slice(5) : "";
  const user = MOCK_DISCORD_USERS.find((u) => u.id === id);
  return user ? { id: user.id, username: user.username, role: user.role, avatar: user.avatar } : null;
}

export async function getSession(): Promise<Session | null> {
  const jar = await cookies();
  return verifySession(jar.get(SESSION_COOKIE)?.value);
}

/** For server components/layouts: redirect to /login when signed out. */
export async function requireSession(): Promise<Session> {
  const s = await getSession();
  if (!s) redirect("/login");
  return s;
}

/** For route handlers: returns the session or null (caller answers 401). */
export async function sessionFromRequest(): Promise<Session | null> {
  return getSession();
}

export function actorName(s: Session) {
  return `${s.username} (Discord)`;
}

/** Game-server → dashboard API auth: `Authorization: Bearer <SENTINEL_DASHBOARD_SECRET>`. */
export function checkServerToken(req: Request): boolean {
  const expected = process.env.SENTINEL_DASHBOARD_SECRET;
  if (!expected) return false;
  const header = req.headers.get("authorization") ?? "";
  const given = header.startsWith("Bearer ") ? header.slice(7) : "";
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}
