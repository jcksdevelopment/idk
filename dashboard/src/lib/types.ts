export type Source = "client" | "server" | "heartbeat" | "vision";
export type Action = "none" | "log" | "screenshot" | "kick" | "ban";

export interface Detection {
  id: string;
  at: string;
  serverId: string;
  player: number;
  name: string;
  code: string;
  source: Source;
  severity: number;
  score: number;
  action: Action;
  evidence: Record<string, unknown>;
  bypass: boolean;
  dryRun: boolean;
}

export interface Player {
  key: string; // serverId:id
  id: number;
  serverId: string;
  name: string;
  identifiers: string[];
  ping: number;
  score: number;
  online: boolean;
  firstSeen: string;
  lastSeen: string;
  detections: number;
  heartbeat: { seq: number; lastValidAt: string; failures: number } | null;
}

export interface Ban {
  id: string;
  name: string;
  identifiers: string[];
  reason: string;
  code: string;
  bannedBy: string;
  createdAt: string;
  expiresAt: string | null;
  /** Set when an unban was requested from the dashboard but the game server hasn't confirmed it yet. */
  pendingUnban?: boolean;
}

export type VerdictKind = "clean" | "suspicious" | "cheat" | "error";

export interface VisionVerdict {
  verdict: VerdictKind;
  confidence: number;
  summary: string;
  findings: { type: string; description: string }[];
  model: string;
  error: string | null;
}

export interface VisionCapture {
  id: string;
  at: string;
  serverId: string;
  player: number;
  name: string;
  reason: string;
  verdict: VisionVerdict;
  imageType: "image/jpeg" | "image/svg+xml";
  review: "pending" | "confirmed" | "dismissed";
  reviewedBy?: string;
}

export type CommandType = "ban" | "unban" | "kick" | "screenshot" | "config" | "reload";

export interface SettingsField {
  key: string;
  label: string;
  type: "bool" | "number" | "string" | "select" | "list" | "codes" | "numbers";
  help?: string;
  min?: number;
  max?: number;
  step?: number;
  options?: string[];
}

export interface SettingsSchema {
  version: number;
  sections: { id: string; title: string; fields: SettingsField[] }[];
}

export interface ServerSettings {
  serverId: string;
  config: Record<string, unknown>;
  schema: SettingsSchema | null;
  updatedAt: string;
  /** True while a change from the dashboard is queued and the game server hasn't confirmed it. */
  pending?: boolean;
}

export interface Command {
  id: string;
  serverId: string;
  type: CommandType;
  player?: number;
  banId?: string;
  reason?: string;
  durationHours?: number;
  /** For bans: lets the game server ban a player who has already disconnected. */
  identifiers?: string[];
  name?: string;
  /** For "config": full settings JSON. */
  config?: string;
  actor: string;
  createdAt: string;
  deliveredAt?: string;
}

export type LogLevel = "debug" | "info" | "warn" | "error" | "crit";

export interface LogLine {
  id: string;
  at: string;
  level: LogLevel;
  kind: string;
  text: string;
  player?: number;
  name?: string;
  code?: string;
}

export interface Session {
  id: string;
  username: string;
  avatar: string;
  role: string;
  exp: number;
}

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  pages: number;
}
