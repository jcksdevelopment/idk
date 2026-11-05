import "server-only";

const g = globalThis as unknown as { __jacServers?: Map<string, number> };
const seen = g.__jacServers ?? (g.__jacServers = new Map());

export function markServerSeen(serverId: string) {
  seen.set(serverId, Date.now());
}

export function isServerConnected(serverId: string) {
  return Date.now() - (seen.get(serverId) ?? 0) < 30_000;
}

export function connectedServers() {
  return [...seen.entries()].filter(([, t]) => Date.now() - t < 30_000).map(([id]) => id);
}
