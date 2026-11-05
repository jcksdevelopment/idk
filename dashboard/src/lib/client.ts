"use client";

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { ...init, headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) } });
  if (res.status === 401) {
    window.location.href = "/login";
    throw new Error("signed out");
  }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error((body as { error?: string }).error ?? `HTTP ${res.status}`);
  return body as T;
}

export function postAction(body: Record<string, unknown>) {
  return api<{ ok: boolean; delivered: string }>("/api/actions", { method: "POST", body: JSON.stringify(body) });
}
