import test from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Store, activate, resetBinding, signToken, hashKey } from "./lib.mjs";

const store = () => new Store(join(mkdtempSync(join(tmpdir(), "jac-lic-")), "l.json"));

test("first activation binds; same server ok; other server refused", () => {
  const s = store();
  const key = s.create({ owner: "server A" });
  assert.match(key, /^JAC-[A-Z0-9X]{5}-[A-Z0-9X]{5}-[A-Z0-9X]{5}-[A-Z0-9X]{5}$/);
  assert.equal(activate(s, { key, fingerprint: "fp1", ip: "1.2.3.4" }).ok, true);
  assert.equal(activate(s, { key, fingerprint: "fp1", ip: "1.2.3.4" }).ok, true);
  assert.equal(activate(s, { key, fingerprint: "fp2", ip: "1.2.3.4" }).ok, false);
  assert.equal(activate(s, { key, fingerprint: "fp1", ip: "5.6.7.8" }).ok, false);
  assert.equal(activate(s, { key: "JAC-NOPE", fingerprint: "fp1", ip: "1.2.3.4" }).ok, false);
});

test("reset moves a license, with a limit; revoke blocks", () => {
  const s = store();
  const key = s.create({ maxResets: 1 });
  activate(s, { key, fingerprint: "a", ip: "1.1.1.1" });
  assert.equal(resetBinding(s, hashKey(key)).ok, true);
  assert.equal(activate(s, { key, fingerprint: "b", ip: "2.2.2.2" }).ok, true);
  assert.equal(resetBinding(s, hashKey(key)).ok, false);
  s.data.licenses[hashKey(key)].revoked = true;
  assert.equal(activate(s, { key, fingerprint: "b", ip: "2.2.2.2" }).ok, false);
});

test("token signature verifies with the public key", () => {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const t = signToken(privateKey.export({ type: "pkcs8", format: "pem" }), { ip: "1.2.3.4", f: "fp", n: "abc", exp: 1 });
  const [b, sig] = t.split(".");
  assert.equal(verify("sha256", Buffer.from(b), publicKey, Buffer.from(sig, "base64url")), true);
  assert.equal(verify("sha256", Buffer.from(b + "x"), publicKey, Buffer.from(sig, "base64url")), false);
});
