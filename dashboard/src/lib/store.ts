import "server-only";
import { EventEmitter } from "node:events";
import { mkdirSync, readFileSync, writeFileSync, existsSync, renameSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import type { Ban, Command, Detection, LogLevel, LogLine, Page, Player, ServerSettings, SettingsSchema, VisionCapture } from "./types";
import { seedDemo, startDemoFeed } from "./demo";

/**
 * In-process store. The game server pushes events into it (POST /api/ingest) and the UI reads from it.
 * State is persisted to .data/state.json (debounced) and screenshots to .data/vision/*.
 * One dashboard instance per deployment: this is a moderation tool, not a multi-region service.
 */

const DATA_DIR = process.env.JCKS_AC_DATA_DIR ?? join(process.cwd(), ".data");
const STATE_FILE = join(DATA_DIR, "state.json");
const VISION_DIR = join(DATA_DIR, "vision");
const MAX_DETECTIONS = 5000;
const MAX_LOG = 1000;
/** Captures kept on disk. Beyond this, dismissed/clean ones go first; confirmed evidence goes last. */
const MAX_VISION = Number(process.env.JCKS_AC_MAX_CAPTURES ?? 1000);

interface State {
  players: Record<string, Player>;
  detections: Detection[];
  bans: Record<string, Ban>;
  vision: VisionCapture[];
  commands: Command[];
  settings: Record<string, ServerSettings>;
}

class Store {
  readonly bus = new EventEmitter();
  private state: State = { players: {}, detections: [], bans: {}, vision: [], commands: [], settings: {} };
  private log: LogLine[] = [];
  private saveTimer: NodeJS.Timeout | null = null;
  readonly demo: boolean;

  constructor() {
    this.bus.setMaxListeners(200);
    mkdirSync(VISION_DIR, { recursive: true });
    if (existsSync(STATE_FILE)) {
      try {
        this.state = { ...this.state, ...JSON.parse(readFileSync(STATE_FILE, "utf8")) };
      } catch (err) {
        console.error("[jcks_anticheat] could not read state, starting empty:", err);
      }
    }
    this.demo = process.env.JCKS_AC_DEMO !== "0";
    this.state.settings ??= {};
    if (this.demo && !this.state.settings.main) this.seedSettingsFromResource();
    if (this.demo && Object.keys(this.state.players).length === 0) {
      seedDemo(this);
    }
    if (this.demo) startDemoFeed(this);
  }

  // ── Writes (ingest + dashboard actions) ────────────────────────────────────────

  upsertPlayer(serverId: string, p: Partial<Player> & { id: number; name: string }, online = true) {
    const key = `${serverId}:${p.id}`;
    const now = new Date().toISOString();
    const prev = this.state.players[key];
    this.state.players[key] = {
      key,
      id: p.id,
      serverId,
      name: p.name,
      identifiers: p.identifiers ?? prev?.identifiers ?? [],
      ping: p.ping ?? prev?.ping ?? 0,
      score: p.score ?? prev?.score ?? 0,
      online,
      firstSeen: prev?.firstSeen ?? now,
      lastSeen: now,
      detections: prev?.detections ?? 0,
      heartbeat: p.heartbeat !== undefined ? p.heartbeat : prev?.heartbeat ?? null,
    };
    this.scheduleSave();
  }

  setOffline(serverId: string, id: number) {
    const p = this.state.players[`${serverId}:${id}`];
    if (p) {
      p.online = false;
      p.lastSeen = new Date().toISOString();
      this.scheduleSave();
    }
  }

  /** Marks every player of a server offline except those in the latest snapshot. */
  syncOnline(serverId: string, onlineIds: Set<number>) {
    for (const p of Object.values(this.state.players)) {
      if (p.serverId === serverId && p.online && !onlineIds.has(p.id)) p.online = false;
    }
  }

  addDetection(d: Omit<Detection, "id">) {
    const det: Detection = { id: randomUUID(), ...d };
    this.state.detections.push(det);
    if (this.state.detections.length > MAX_DETECTIONS) this.state.detections.splice(0, this.state.detections.length - MAX_DETECTIONS);
    const p = this.state.players[`${d.serverId}:${d.player}`];
    if (p) {
      p.detections += 1;
      p.score = d.score;
    }
    const level: LogLevel = d.action === "ban" ? "crit" : d.action === "kick" ? "error" : d.severity >= 30 ? "warn" : "info";
    const flags = [d.dryRun ? "dry-run" : "", d.bypass ? "bypass" : ""].filter(Boolean).join(",");
    this.pushLog({
      at: d.at,
      level,
      kind: "detection",
      player: d.player,
      name: d.name,
      code: d.code,
      text: `${d.code.padEnd(22)} ${d.name} (#${d.player}) sev=${d.severity} score=${d.score.toFixed(0)} → ${d.action}${flags ? ` [${flags}]` : ""} ${summarise(d.evidence)}`,
    });
    this.scheduleSave();
    return det;
  }

  addBan(b: Ban) {
    this.state.bans[b.id] = { ...b, pendingUnban: false };
    this.pushLog({ at: b.createdAt, level: "crit", kind: "ban", text: `BAN ${b.id} ${b.name}: ${b.reason} (by ${b.bannedBy})` });
    this.scheduleSave();
  }

  removeBan(id: string, actor?: string) {
    const b = this.state.bans[id];
    if (!b) return;
    delete this.state.bans[id];
    this.pushLog({ level: "info", kind: "unban", text: `UNBAN ${id} ${b.name}${actor ? ` (by ${actor})` : ""}` });
    this.scheduleSave();
  }

  markPendingUnban(id: string) {
    const b = this.state.bans[id];
    if (b) b.pendingUnban = true;
    this.scheduleSave();
  }

  addVision(capture: VisionCapture, image?: Buffer) {
    if (image) writeFileSync(join(VISION_DIR, `${capture.id}${capture.imageType === "image/svg+xml" ? ".svg" : ".jpg"}`), image);
    this.state.vision.unshift(capture);
    this.enforceVisionRetention();
    const v = capture.verdict;
    this.pushLog({
      at: capture.at,
      level: v.verdict === "cheat" ? "error" : v.verdict === "suspicious" ? "warn" : v.verdict === "error" ? "warn" : "info",
      kind: "vision",
      player: capture.player,
      name: capture.name,
      text: `VISION ${capture.name} (#${capture.player}) ${v.verdict} ${(v.confidence * 100).toFixed(0)}% ${v.error ?? v.summary}`,
    });
    this.scheduleSave();
  }

  private enforceVisionRetention() {
    const excess = this.state.vision.length - MAX_VISION;
    if (excess <= 0) return;
    // Removal order: dismissed, then clean/error verdicts, then pending, then confirmed; oldest first within each.
    const rank = (c: VisionCapture) =>
      c.review === "dismissed" ? 0 : c.verdict.verdict === "clean" || c.verdict.verdict === "error" ? 1 : c.review === "pending" ? 2 : 3;
    const victims = [...this.state.vision]
      .sort((a, b) => rank(a) - rank(b) || a.at.localeCompare(b.at))
      .slice(0, excess);
    const drop = new Set(victims.map((v) => v.id));
    this.state.vision = this.state.vision.filter((v) => !drop.has(v.id));
    for (const v of victims) {
      const file = join(VISION_DIR, `${v.id}${v.imageType === "image/svg+xml" ? ".svg" : ".jpg"}`);
      try {
        if (existsSync(file)) unlinkSync(file);
      } catch (err) {
        console.error("[jcks_anticheat] could not delete capture", v.id, err);
      }
    }
  }

  reviewVision(id: string, review: "confirmed" | "dismissed", actor: string) {
    const c = this.state.vision.find((x) => x.id === id);
    if (!c) return null;
    c.review = review;
    c.reviewedBy = actor;
    this.scheduleSave();
    return c;
  }

  queueCommand(cmd: Omit<Command, "id" | "createdAt">) {
    const c: Command = { ...cmd, id: randomUUID(), createdAt: new Date().toISOString() };
    this.state.commands.push(c);
    this.pushLog({ level: "info", kind: "command", text: `queued ${c.type} ${c.player !== undefined ? `#${c.player}` : c.banId ?? ""} for ${c.serverId} by ${c.actor}` });
    this.scheduleSave();
    return c;
  }

  /** Hands undelivered commands to the game server and marks them delivered. */
  takeCommands(serverId: string): Command[] {
    const now = new Date().toISOString();
    const out = this.state.commands.filter((c) => c.serverId === serverId && !c.deliveredAt);
    for (const c of out) c.deliveredAt = now;
    // Keep a short history only.
    this.state.commands = this.state.commands.filter((c) => !c.deliveredAt || Date.now() - Date.parse(c.deliveredAt) < 86_400_000);
    if (out.length) this.scheduleSave();
    return out;
  }

  pushLog(line: Omit<LogLine, "id" | "at"> & { at?: string }) {
    const l: LogLine = { id: randomUUID(), at: line.at ?? new Date().toISOString(), ...line };
    this.log.push(l);
    if (this.log.length > MAX_LOG) this.log.splice(0, this.log.length - MAX_LOG);
    this.bus.emit("log", l);
  }

  // ── Live settings ───────────────────────────────────────────────────────────────

  setSettings(serverId: string, config: Record<string, unknown>, schema: SettingsSchema | null) {
    const prev = this.state.settings[serverId];
    this.state.settings[serverId] = { serverId, config, schema: schema ?? prev?.schema ?? null, updatedAt: new Date().toISOString(), pending: false };
    this.scheduleSave();
  }

  markSettingsPending(serverId: string) {
    const s = this.state.settings[serverId];
    if (s) s.pending = true;
  }

  settings(serverId: string): ServerSettings | null {
    return this.state.settings[serverId] ?? null;
  }

  /** Demo mode: start from the resource's shipped config.json + schema when the repo layout is present. */
  private seedSettingsFromResource() {
    const dir = join(process.cwd(), "..", "resource", "jcks_anticheat");
    try {
      const config = JSON.parse(readFileSync(join(dir, "config.json"), "utf8"));
      const schema = JSON.parse(readFileSync(join(dir, "settings.schema.json"), "utf8"));
      this.state.settings.main = { serverId: "main", config, schema, updatedAt: new Date().toISOString() };
    } catch {
      // Not running from the repository; settings appear once a game server pushes them.
    }
  }

  // ── Reads ───────────────────────────────────────────────────────────────────────

  recentLog(limit = 200): LogLine[] {
    return [...this.log].sort((a, b) => a.at.localeCompare(b.at)).slice(-limit);
  }

  players(opts: { q?: string; page?: number; pageSize?: number; status?: "online" | "all" }): Page<Player> {
    const q = opts.q?.toLowerCase().trim();
    let items = Object.values(this.state.players);
    if (opts.status === "online") items = items.filter((p) => p.online);
    if (q) items = items.filter((p) => p.name.toLowerCase().includes(q) || String(p.id) === q || p.identifiers.some((i) => i.toLowerCase().includes(q)));
    items.sort((a, b) => Number(b.online) - Number(a.online) || b.score - a.score || a.name.localeCompare(b.name));
    return paginate(items, opts.page, opts.pageSize);
  }

  player(key: string) {
    return this.state.players[key] ?? null;
  }

  bans(opts: { q?: string; page?: number; pageSize?: number }): Page<Ban> {
    const q = opts.q?.toLowerCase().trim();
    let items = Object.values(this.state.bans);
    if (q) items = items.filter((b) => [b.id, b.name, b.reason, b.code, b.bannedBy, ...b.identifiers].some((s) => s.toLowerCase().includes(q)));
    items.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return paginate(items, opts.page, opts.pageSize);
  }

  ban(id: string) {
    return this.state.bans[id] ?? null;
  }

  detections(opts: { player?: string; limit?: number }): Detection[] {
    let items = this.state.detections;
    if (opts.player) items = items.filter((d) => `${d.serverId}:${d.player}` === opts.player);
    return items.slice(-(opts.limit ?? 100)).reverse();
  }

  vision(filter: "all" | "pending" | "cheat" = "all"): VisionCapture[] {
    if (filter === "pending") return this.state.vision.filter((v) => v.review === "pending");
    if (filter === "cheat") return this.state.vision.filter((v) => v.verdict.verdict === "cheat");
    return this.state.vision;
  }

  visionImage(id: string): { data: Buffer; type: string } | null {
    const c = this.state.vision.find((v) => v.id === id);
    if (!c || !/^[\w-]+$/.test(id)) return null;
    const file = join(VISION_DIR, `${id}${c.imageType === "image/svg+xml" ? ".svg" : ".jpg"}`);
    if (!existsSync(file)) return null;
    return { data: readFileSync(file), type: c.imageType };
  }

  stats() {
    const players = Object.values(this.state.players);
    const dayAgo = Date.now() - 86_400_000;
    const recent = this.state.detections.filter((d) => Date.parse(d.at) > dayAgo);
    return {
      online: players.filter((p) => p.online).length,
      tracked: players.length,
      detections24h: recent.length,
      actions24h: recent.filter((d) => d.action === "kick" || d.action === "ban").length,
      bans: Object.keys(this.state.bans).length,
      pendingReview: this.state.vision.filter((v) => v.review === "pending").length,
    };
  }

  private scheduleSave() {
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      try {
        const tmp = STATE_FILE + ".tmp";
        writeFileSync(tmp, JSON.stringify(this.state));
        renameSync(tmp, STATE_FILE);
      } catch (err) {
        console.error("[jcks_anticheat] could not save state:", err);
      }
    }, 1000);
  }
}

function paginate<T>(items: T[], page = 1, pageSize = 25): Page<T> {
  const size = Math.min(Math.max(pageSize, 5), 100);
  const pages = Math.max(1, Math.ceil(items.length / size));
  const p = Math.min(Math.max(1, page), pages);
  return { items: items.slice((p - 1) * size, p * size), total: items.length, page: p, pageSize: size, pages };
}

function summarise(evidence: Record<string, unknown>) {
  const parts = Object.entries(evidence ?? {})
    .slice(0, 4)
    .map(([k, v]) => `${k}=${typeof v === "object" ? JSON.stringify(v) : String(v)}`);
  return parts.length ? `{${parts.join(" ")}}` : "";
}

// Survive Next.js dev hot reloads: one store per process.
const g = globalThis as unknown as { __jacStore?: Store };
export const store: Store = g.__jacStore ?? (g.__jacStore = new Store());
export type { Store };
