import { createHash, createPrivateKey, randomBytes, sign, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";

export const TOKEN_TTL_SECONDS = 24 * 3600;

export function hashKey(key) {
  return createHash("sha256").update(String(key).trim()).digest("hex");
}

export function newLicenseKey() {
  const raw = randomBytes(15).toString("base64url").toUpperCase().replace(/[^A-Z0-9]/g, "X");
  return `JAC-${raw.slice(0, 5)}-${raw.slice(5, 10)}-${raw.slice(10, 15)}-${raw.slice(15, 20)}`;
}

export class Store {
  constructor(path) {
    this.path = path;
    this.data = existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : { licenses: {} };
  }
  save() {
    const tmp = this.path + ".tmp";
    writeFileSync(tmp, JSON.stringify(this.data, null, 2));
    renameSync(tmp, this.path);
  }
  create({ owner = "", note = "", maxResets = 3 } = {}) {
    const key = newLicenseKey();
    this.data.licenses[hashKey(key)] = {
      owner, note, createdAt: new Date().toISOString(), revoked: false, binding: null, resets: 0, maxResets, lastSeen: null, lastIp: null,
    };
    this.save();
    return key;
  }
  get(key) {
    return this.data.licenses[hashKey(key)] ?? null;
  }
  list() {
    return Object.entries(this.data.licenses).map(([id, l]) => ({ id: id.slice(0, 12), ...l }));
  }
  findById(prefix) {
    const hit = Object.keys(this.data.licenses).filter((h) => h.startsWith(prefix));
    return hit.length === 1 ? hit[0] : null;
  }
}

export function activate(store, { key, fingerprint, ip, now = new Date() }) {
  const lic = store.get(key);
  if (!lic) return { ok: false, reason: "unknown license key" };
  if (lic.revoked) return { ok: false, reason: "license revoked" };
  if (!fingerprint || typeof fingerprint !== "string" || fingerprint.length > 128) return { ok: false, reason: "bad fingerprint" };
  if (!lic.binding) {
    lic.binding = { ip, fingerprint, boundAt: now.toISOString() };
  } else if (lic.binding.ip !== ip || lic.binding.fingerprint !== fingerprint) {
    return { ok: false, reason: "license is bound to another server; ask the seller to reset it" };
  }
  lic.lastSeen = now.toISOString();
  lic.lastIp = ip;
  store.save();
  return { ok: true, license: lic };
}

export function resetBinding(store, id) {
  const lic = store.data.licenses[id];
  if (!lic) return { ok: false, reason: "not found" };
  if (lic.resets >= lic.maxResets) return { ok: false, reason: "reset limit reached" };
  lic.binding = null;
  lic.resets += 1;
  store.save();
  return { ok: true };
}

export function signToken(privateKeyPem, payload) {
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const sig = sign("sha256", Buffer.from(body), createPrivateKey(privateKeyPem)).toString("base64url");
  return `${body}.${sig}`;
}

export function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}
