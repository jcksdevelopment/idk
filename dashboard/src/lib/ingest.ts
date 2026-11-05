import "server-only";
import { store } from "./store";
import type { Action, Ban, SettingsSchema, Source, VisionVerdict } from "./types";

type Obj = Record<string, unknown>;
const str = (v: unknown, d = "") => (typeof v === "string" ? v : d);
const num = (v: unknown, d = 0) => (typeof v === "number" && Number.isFinite(v) ? v : d);
const obj = (v: unknown): Obj => (v && typeof v === "object" && !Array.isArray(v) ? (v as Obj) : {});

const SOURCES = new Set(["client", "server", "heartbeat", "vision"]);
const ACTIONS = new Set(["none", "log", "screenshot", "kick", "ban"]);

/** Applies one event pushed by JcksAnticheat.Core.Dashboard.DashboardBridge. Unknown types are ignored. */
export function applyEvent(serverId: string, ev: Obj) {
  const type = str(ev.type);
  const at = str(ev.at, new Date().toISOString());
  const data = ev.data;

  switch (type) {
    case "detection": {
      const d = obj(data);
      const player = num(d.player);
      const name = str(d.name, `#${player}`);
      if (!store.player(`${serverId}:${player}`)) store.upsertPlayer(serverId, { id: player, name });
      store.addDetection({
        at,
        serverId,
        player,
        name,
        code: str(d.code, "UNKNOWN").slice(0, 48),
        source: (SOURCES.has(str(d.source)) ? str(d.source) : "server") as Source,
        severity: num(d.severity),
        score: num(d.score),
        action: (ACTIONS.has(str(d.action)) ? str(d.action) : "log") as Action,
        evidence: obj(d.evidence),
        bypass: d.bypass === true,
        dryRun: d.dryRun === true,
      });
      break;
    }
    case "players": {
      const list = Array.isArray(data) ? data.map(obj) : [];
      const online = new Set<number>();
      for (const p of list) {
        const id = num(p.id);
        online.add(id);
        const hb = obj(p.heartbeat);
        store.upsertPlayer(serverId, {
          id,
          name: str(p.name, `#${id}`),
          identifiers: Array.isArray(p.identifiers) ? p.identifiers.filter((x): x is string => typeof x === "string") : [],
          ping: num(p.ping),
          score: num(p.score),
          heartbeat: p.heartbeat ? { seq: num(hb.seq), lastValidAt: str(hb.lastValidAt), failures: num(hb.failures) } : null,
        });
      }
      store.syncOnline(serverId, online);
      break;
    }
    case "player_joined": {
      const p = obj(data);
      store.upsertPlayer(serverId, { id: num(p.id), name: str(p.name), identifiers: Array.isArray(p.identifiers) ? (p.identifiers as string[]) : [] });
      store.pushLog({ level: "debug", kind: "join", text: `${str(p.name)} (#${num(p.id)}) completed handshake` });
      break;
    }
    case "player_left": {
      const p = obj(data);
      store.setOffline(serverId, num(p.id));
      store.pushLog({ level: "debug", kind: "leave", text: `${str(p.name)} (#${num(p.id)}) left: ${str(p.reason)}` });
      break;
    }
    case "ban": {
      const b = obj(data);
      const ban: Ban = {
        id: str(b.id),
        name: str(b.name),
        identifiers: Array.isArray(b.identifiers) ? b.identifiers.filter((x): x is string => typeof x === "string") : [],
        reason: str(b.reason),
        code: str(b.code),
        bannedBy: str(b.bannedBy, "jcks_anticheat"),
        createdAt: str(b.createdAt, at),
        expiresAt: typeof b.expiresAt === "string" ? b.expiresAt : null,
      };
      if (ban.id) store.addBan(ban);
      break;
    }
    case "unban": {
      const b = obj(data);
      store.removeBan(str(b.id), str(b.actor) || undefined);
      break;
    }
    case "vision": {
      const v = obj(data);
      const verdict = obj(v.verdict);
      const image = str(v.image);
      const kind = str(verdict.verdict);
      store.addVision(
        {
          id: str(v.id).replace(/[^\w-]/g, "").slice(0, 64) || crypto.randomUUID(),
          at,
          serverId,
          player: num(v.player),
          name: str(v.name),
          reason: str(v.reason),
          verdict: {
            verdict: (["clean", "suspicious", "cheat", "error"].includes(kind) ? kind : "error") as VisionVerdict["verdict"],
            confidence: num(verdict.confidence),
            summary: str(verdict.summary),
            findings: Array.isArray(verdict.findings) ? verdict.findings.map(obj).map((f) => ({ type: str(f.type), description: str(f.description) })) : [],
            model: str(verdict.model),
            error: typeof verdict.error === "string" ? verdict.error : null,
          },
          imageType: "image/jpeg",
          review: "pending",
        },
        image ? Buffer.from(image, "base64") : undefined,
      );
      break;
    }
    case "settings": {
      const s = obj(data);
      store.setSettings(serverId, obj(s.config), s.schema && typeof s.schema === "object" ? (s.schema as SettingsSchema) : null);
      break;
    }
    case "settings_changed": {
      const s = obj(data);
      store.pushLog({ level: "warn", kind: "settings", text: `settings ${s.saved ? "saved" : "reloaded"} by ${str(s.actor)}` });
      break;
    }
    case "connection_rejected": {
      const c = obj(data);
      store.pushLog({ level: "warn", kind: "connect", text: `rejected banned connection ${str(c.name)} (ban ${str(c.banId)})` });
      break;
    }
  }
}
