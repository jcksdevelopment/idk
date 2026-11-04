import "server-only";

const g = globalThis as unknown as { __sentinelServers?: Map<string, number> };
const seen = g.__sentinelServers ?? (g.__sentinelServers = new Map());

export function markServerSeen(serverId: string) {
  seen.set(serverId, Date.now());
}

/** A game server counts as connected if it pushed or polled in the last 30 seconds. */
export function isServerConnected(serverId: string) {
  return Date.now() - (seen.get(serverId) ?? 0) < 30_000;
}

export function connectedServers() {
  return [...seen.entries()].filter(([, t]) => Date.now() - t < 30_000).map(([id]) => id);
}
