import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { Store, activate, resetBinding, signToken, safeEqual, TOKEN_TTL_SECONDS } from "./lib.mjs";

const DATA = process.env.JAC_LICENSE_DATA ?? "./data";
const PORT = Number(process.env.PORT ?? 8787);
const ADMIN = process.env.JAC_LICENSE_ADMIN_TOKEN ?? "";
const TRUST_PROXY = process.env.JAC_TRUST_PROXY === "1";
const privateKey = readFileSync(`${DATA}/license.key.pem`, "utf8");
const store = new Store(`${DATA}/licenses.json`);

const hits = new Map();
function limited(ip) {
  const now = Date.now();
  const h = (hits.get(ip) ?? []).filter((t) => now - t < 60_000);
  h.push(now);
  hits.set(ip, h);
  return h.length > 30;
}

function clientIp(req) {
  if (TRUST_PROXY) {
    const fwd = String(req.headers["x-forwarded-for"] ?? "").split(",")[0].trim();
    if (fwd) return fwd;
  }
  return (req.socket.remoteAddress ?? "").replace(/^::ffff:/, "");
}

async function body(req) {
  let size = 0;
  const chunks = [];
  for await (const c of req) {
    size += c.length;
    if (size > 16 * 1024) throw new Error("too large");
    chunks.push(c);
  }
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString("utf8")) : {};
}

function send(res, status, obj) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
}

const admin = (req) => ADMIN.length >= 16 && safeEqual(String(req.headers.authorization ?? ""), `Bearer ${ADMIN}`);

createServer(async (req, res) => {
  const ip = clientIp(req);
  try {
    if (limited(ip)) return send(res, 429, { error: "slow down" });

    if (req.method === "POST" && req.url === "/v1/activate") {
      const { key, fingerprint, nonce, version } = await body(req);
      const r = activate(store, { key, fingerprint, ip });
      if (!r.ok) return send(res, 403, { error: r.reason });
      const now = Math.floor(Date.now() / 1000);
      const token = signToken(privateKey, {
        k: String(key).slice(-5), ip, f: fingerprint, n: String(nonce ?? "").slice(0, 64), v: String(version ?? "").slice(0, 32),
        iat: now, exp: now + TOKEN_TTL_SECONDS,
      });
      return send(res, 200, { token });
    }

    if (req.url?.startsWith("/v1/admin/")) {
      if (!admin(req)) return send(res, 401, { error: "unauthorized" });
      if (req.method === "GET" && req.url === "/v1/admin/licenses") return send(res, 200, { licenses: store.list() });
      if (req.method === "POST" && req.url === "/v1/admin/licenses") {
        const { owner, note, maxResets } = await body(req);
        return send(res, 200, { key: store.create({ owner, note, maxResets }) });
      }
      if (req.method === "POST" && (req.url === "/v1/admin/reset" || req.url === "/v1/admin/revoke")) {
        const { id } = await body(req);
        const full = store.findById(String(id ?? ""));
        if (!full) return send(res, 404, { error: "not found or ambiguous id" });
        if (req.url === "/v1/admin/reset") {
          const r = resetBinding(store, full);
          return send(res, r.ok ? 200 : 400, r);
        }
        store.data.licenses[full].revoked = true;
        store.save();
        return send(res, 200, { ok: true });
      }
    }
    send(res, 404, { error: "not found" });
  } catch (e) {
    send(res, 400, { error: String(e.message ?? e) });
  }
}).listen(PORT, () => console.log(`license server on :${PORT}`));
