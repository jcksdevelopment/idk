import { generateKeyPairSync } from "node:crypto";
import { writeFileSync, existsSync, mkdirSync } from "node:fs";

const dir = process.env.JAC_LICENSE_DATA ?? "./data";
mkdirSync(dir, { recursive: true });
const privPath = `${dir}/license.key.pem`;
if (existsSync(privPath)) {
  console.error(`${privPath} already exists; refusing to overwrite it (every licensed build trusts its public key).`);
  process.exit(1);
}
const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
writeFileSync(privPath, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
const pub = publicKey.export({ type: "spki", format: "pem" });
writeFileSync(`${dir}/license.pub.pem`, pub);
console.log(`private key: ${privPath} (keep it secret, back it up)`);
console.log(`public key:  ${dir}/license.pub.pem`);
console.log("copy the public key to server-src/JcksAnticheat.Server/license.pub.pem and rebuild the resource.");
