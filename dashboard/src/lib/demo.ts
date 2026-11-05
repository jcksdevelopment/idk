import type { Store } from "./store";
import type { Action, Source, VisionCapture } from "./types";

/**
 * Demo mode (default unless JCKS_AC_DEMO=0): seeds believable data and streams a detection every few
 * seconds, so the dashboard can be evaluated without a running FiveM server. Real ingest works
 * alongside it; set JCKS_AC_DEMO=0 in production.
 */

const NAMES = [
  "Marcus Vane", "lilbrick", "Ava_Kowalski", "Tony Moretti", "xXSnipeGodXx", "Jules Okafor", "DeltaNine", "Rosa Delgado",
  "kenji.r", "BigSmokeRP", "Nadia Petrova", "frost", "Eli Carter", "MoneyMike", "Sven Holm", "notacheater",
  "Priya Shah", "Dutch", "Cassie Wren", "Officer Lang", "M4verick", "Hugo Brandt", "zz_ghost", "Leila Haddad",
  "Pete Ruiz", "chaos.exe", "Ines Duarte", "Wade Fisher", "Kofi Mensah", "luna", "Grim", "Tomasz Nowak",
  "Rex Calloway", "Maya Lin", "Quinn", "Darius Cole", "yeet_master", "Olga Ivanova", "Benji", "Sam Archer",
];

const CODES: { code: string; source: Source; sev: number }[] = [
  { code: "MOV_TELEPORT", source: "server", sev: 40 },
  { code: "PLY_GODMODE_FLAG", source: "client", sev: 40 },
  { code: "WPN_AIM_ANGLE", source: "server", sev: 30 },
  { code: "WPN_HEADSHOT_RATIO", source: "server", sev: 30 },
  { code: "PLY_SPEED_FOOT", source: "server", sev: 30 },
  { code: "MOV_FREECAM", source: "client", sev: 25 },
  { code: "WPN_RANGE", source: "server", sev: 25 },
  { code: "PLY_HEALTH_REGEN", source: "server", sev: 25 },
  { code: "NET_RATE", source: "server", sev: 20 },
  { code: "VEH_HANDLING", source: "client", sev: 30 },
  { code: "EXE_RESOURCE_INJECT", source: "client", sev: 50 },
  { code: "WPN_EXPLOSIVE_AMMO", source: "server", sev: 50 },
  { code: "HB_MISSING", source: "heartbeat", sev: 60 },
  { code: "PLY_STAMINA", source: "client", sev: 10 },
  { code: "NUI_DEVTOOLS", source: "client", sev: 40 },
];

const EVIDENCE: Record<string, () => Record<string, unknown>> = {
  MOV_TELEPORT: () => ({ dist: rnd(80, 2400, 1), dt: 1.0, mode: pick(["OnFoot", "LandVehicle"]) }),
  PLY_GODMODE_FLAG: () => ({ inv: true, dmg: false }),
  WPN_AIM_ANGLE: () => ({ weapon: "WEAPON_CARBINERIFLE", angle: rnd(62, 170, 1), dist: rnd(10, 80, 1) }),
  WPN_HEADSHOT_RATIO: () => ({ ratio: rnd(0.72, 0.96, 2), n: 25 }),
  PLY_SPEED_FOOT: () => ({ speed: rnd(14, 40, 1), max: 16.2, mode: "OnFoot" }),
  MOV_FREECAM: () => ({ d: Math.round(rnd(52, 400)), kind: "rendered" }),
  WPN_RANGE: () => ({ weapon: "WEAPON_PISTOL", dist: rnd(160, 600, 1), max: 150 }),
  PLY_HEALTH_REGEN: () => ({ from: Math.round(rnd(110, 150)), to: 200 }),
  NET_RATE: () => ({ bucket: pick(["weaponDamage", "heartbeat", "qb-inventory:server:SetInventoryData"]) }),
  VEH_HANDLING: () => ({ f: "fInitialDriveForce", b: 0.32, v: rnd(1.2, 4, 2) }),
  EXE_RESOURCE_INJECT: () => ({ r: pick(["_cfx_internal", "skript", "redENGINE", "monitor_"]) }),
  WPN_EXPLOSIVE_AMMO: () => ({ type: 18, scale: 1, rate: Math.round(rnd(1, 20)) }),
  HB_MISSING: () => ({ silentSec: Math.round(rnd(21, 60)) }),
  PLY_STAMINA: () => ({ ms: Math.round(rnd(25000, 60000)) }),
  NUI_DEVTOOLS: () => ({ how: pick(["console-getter", "debugger-timing"]) }),
};

function rnd(min: number, max: number, decimals = 0) {
  const f = 10 ** decimals;
  return Math.round((min + Math.random() * (max - min)) * f) / f;
}
function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}
function hex(n: number) {
  return Array.from({ length: n }, () => Math.floor(Math.random() * 16).toString(16)).join("");
}
function identifiers() {
  return [`license:${hex(40)}`, `discord:${Math.floor(1e17 + Math.random() * 9e17)}`, `fivem:${Math.floor(rnd(100000, 9999999))}`];
}

function emitDetection(store: Store, at = new Date()) {
  const players = store.players({ status: "online", pageSize: 100 }).items;
  if (!players.length) return;
  const p = pick(players);
  const c = pick(CODES);
  // Most players trip one check now and then; a few keep escalating. Mirrors the decaying ledger.
  const repeat = Math.random() < 0.25;
  const score = Math.min(200, (repeat ? p.score * 0.9 : p.score * 0.2) + c.sev * (repeat ? 1 : 0.6));
  const action: Action = score >= 140 ? "ban" : score >= 80 ? "kick" : score >= 40 ? "screenshot" : "log";
  store.addDetection({
    at: at.toISOString(),
    serverId: "main",
    player: p.id,
    name: p.name,
    code: c.code,
    source: c.source,
    severity: c.sev,
    score,
    action,
    evidence: EVIDENCE[c.code]?.() ?? {},
    bypass: false,
    dryRun: false,
  });
}

export function seedDemo(store: Store) {
  NAMES.forEach((name, i) => {
    store.upsertPlayer("main", {
      id: i + 1,
      name,
      identifiers: identifiers(),
      ping: Math.round(rnd(18, 140)),
      score: 0,
      heartbeat: { seq: Math.round(rnd(20, 900)), lastValidAt: new Date().toISOString(), failures: 0 },
    }, i < 32);
  });

  const now = Date.now();
  for (let i = 0; i < 160; i++) emitDetection(store, new Date(now - (160 - i) * 90_000));

  const reasons = ["Automated: MOV_TELEPORT", "Automated: WPN_EXPLOSIVE_AMMO", "Automated: HB_INVALID", "Mod menu confirmed in Vision Vault", "Automated: VEH_SPAWN", "Combat logging + aimbot report"];
  for (let i = 0; i < 37; i++) {
    const created = new Date(now - rnd(1, 90) * 86_400_000);
    store.addBan({
      id: hex(12),
      name: `${pick(["ghost", "Dex", "Nova", "Raze", "Kilo", "Vex", "Juno", "Rook"])}${Math.floor(rnd(1, 999))}`,
      identifiers: identifiers(),
      reason: pick(reasons),
      code: pick(["MOV_TELEPORT", "WPN_EXPLOSIVE_AMMO", "HB_INVALID", "MANUAL", "VEH_SPAWN"]),
      bannedBy: pick(["jcks_anticheat", "jcks_anticheat", "jcks_anticheat", "Mara (Discord)", "Theo (Discord)"]),
      createdAt: created.toISOString(),
      expiresAt: Math.random() < 0.3 ? new Date(created.getTime() + 7 * 86_400_000).toISOString() : null,
    });
  }

  const captures: { kind: FrameKind; verdict: VisionCapture["verdict"] }[] = [
    { kind: "menu", verdict: { verdict: "cheat", confidence: 0.94, summary: "Injected mod menu with Godmode and Noclip toggles on the left side.", findings: [{ type: "mod_menu", description: "Overlay list titled with menu watermark; options Godmode, Noclip, Spawn Vehicle" }], model: "claude-opus-5-5", error: null } },
    { kind: "esp", verdict: { verdict: "cheat", confidence: 0.88, summary: "ESP boxes and snap lines drawn to three players behind a wall.", findings: [{ type: "esp_box", description: "Rectangles around 3 peds, two occluded by buildings" }, { type: "esp_line", description: "Lines from screen bottom-centre to each box" }], model: "claude-opus-5-5", error: null } },
    { kind: "fov", verdict: { verdict: "suspicious", confidence: 0.61, summary: "Circle around the crosshair consistent with an aimbot FOV indicator.", findings: [{ type: "fov_circle", description: "Thin white circle, radius about 15% of screen height" }], model: "claude-opus-5-5", error: null } },
    { kind: "clean", verdict: { verdict: "clean", confidence: 0.12, summary: "Normal HUD: minimap, status bars and a server notification.", findings: [], model: "claude-opus-5-5", error: null } },
    { kind: "clean", verdict: { verdict: "clean", confidence: 0.08, summary: "Driving view with speedometer; no overlays.", findings: [], model: "claude-opus-5-5", error: null } },
    { kind: "esp", verdict: { verdict: "cheat", confidence: 0.83, summary: "Name and distance labels above distant players, drawn through terrain.", findings: [{ type: "esp_text", description: "Labels like 'Tony [212m]' over occluded peds" }], model: "claude-opus-5-5", error: null } },
  ];
  captures.forEach((c, i) => {
    const p = pick(NAMES.slice(0, 32));
    const id = `demo-${hex(10)}`;
    store.addVision({
      id,
      at: new Date(now - (i + 1) * 47 * 60_000).toISOString(),
      serverId: "main",
      player: NAMES.indexOf(p) + 1,
      name: p,
      reason: pick(["MOV_TELEPORT (score 52)", "WPN_AIM_ANGLE (score 61)", "manual request by Mara", "WPN_HEADSHOT_RATIO before kick"]),
      verdict: c.verdict,
      imageType: "image/svg+xml",
      review: i < 4 ? "pending" : i === 4 ? "dismissed" : "confirmed",
      reviewedBy: i >= 4 ? "Mara (Discord)" : undefined,
    }, Buffer.from(frameSvg(c.kind)));
  });
}

export function startDemoFeed(store: Store) {
  const g = globalThis as unknown as { __jacDemoFeed?: NodeJS.Timeout };
  if (g.__jacDemoFeed) return;
  const tick = () => {
    emitDetection(store);
    g.__jacDemoFeed = setTimeout(tick, rnd(2500, 7000));
  };
  g.__jacDemoFeed = setTimeout(tick, 3000);
  g.__jacDemoFeed.unref?.();
}

type FrameKind = "menu" | "esp" | "fov" | "clean";

/** Stand-in "game frame" for demo captures: sky, skyline, road, HUD, plus the overlay being demonstrated. */
function frameSvg(kind: FrameKind) {
  const skyline = Array.from({ length: 14 }, (_, i) => {
    const w = 60 + ((i * 37) % 50);
    const h = 120 + ((i * 71) % 180);
    return `<rect x="${i * 70 - 10}" y="${400 - h}" width="${w}" height="${h}" fill="#1b2433" />`;
  }).join("");
  const peds = [
    [380, 330],
    [610, 345],
    [820, 320],
  ];
  const pedShapes = peds.map(([x, y]) => `<rect x="${x}" y="${y}" width="16" height="44" rx="6" fill="#2a3242" />`).join("");
  let overlay = "";
  if (kind === "esp") {
    overlay = peds
      .map(([x, y], i) => `<rect x="${x - 10}" y="${y - 10}" width="36" height="64" fill="none" stroke="#ff3b3b" stroke-width="2"/>
<line x1="640" y1="720" x2="${x + 8}" y2="${y + 54}" stroke="#ff3b3b" stroke-width="1.5"/>
<text x="${x - 10}" y="${y - 16}" fill="#ffd400" font-family="monospace" font-size="13">${["Tony", "Rosa", "Dutch"][i]} [${[212, 97, 341][i]}m]</text>`)
      .join("");
  } else if (kind === "fov") {
    overlay = `<circle cx="640" cy="360" r="110" fill="none" stroke="#ffffff" stroke-opacity="0.85" stroke-width="1.5"/>`;
  } else if (kind === "menu") {
    const items = ["Self", "  Godmode        [ON]", "  Noclip         [OFF]", "  Super Jump     [ON]", "Weapons", "Vehicle Spawner", "Online Players", "Teleport to Waypoint", "Settings"];
    overlay = `<rect x="40" y="90" width="300" height="${44 + items.length * 30}" fill="#0b0b10" fill-opacity="0.92" stroke="#7c3aed"/>
<rect x="40" y="90" width="300" height="40" fill="#7c3aed"/>
<text x="56" y="117" fill="#fff" font-family="sans-serif" font-weight="700" font-size="18">PHANTOM MENU v3</text>
${items.map((t, i) => `<rect x="40" y="${134 + i * 30}" width="300" height="30" fill="${i === 1 ? "#7c3aed" : "none"}" fill-opacity="0.35"/><text x="56" y="${155 + i * 30}" fill="#e5e7eb" font-family="monospace" font-size="14" xml:space="preserve">${t}</text>`).join("")}`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a4a66"/><stop offset="1" stop-color="#8a7a6a"/></linearGradient></defs>
<rect width="1280" height="720" fill="url(#sky)"/>${skyline}
<rect y="400" width="1280" height="320" fill="#2b2b2e"/>
<polygon points="560,400 720,400 1100,720 180,720" fill="#3a3a3e"/>
<rect x="636" y="420" width="8" height="40" fill="#d9d9d9"/><rect x="636" y="520" width="8" height="60" fill="#d9d9d9"/>
${pedShapes}
<rect x="1100" y="560" width="150" height="130" rx="6" fill="#0d1117" fill-opacity="0.8"/><circle cx="1175" cy="625" r="4" fill="#38bdf8"/>
<rect x="30" y="690" width="160" height="8" fill="#16a34a"/><rect x="30" y="702" width="120" height="6" fill="#2563eb"/>
<line x1="634" y1="360" x2="646" y2="360" stroke="#fff"/><line x1="640" y1="354" x2="640" y2="366" stroke="#fff"/>
${overlay}
</svg>`;
}
