"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { Ban, Detection, DetectionStats, Player } from "@/lib/types";
import { Badge, cx, Empty, timeAgo } from "./ui";

type Data = {
  stats: { online: number; tracked: number; detections24h: number; actions24h: number; bans: number; pendingReview: number };
  day: DetectionStats;
  recent: Detection[];
  bans: Ban[];
  top: Player[];
  server: { connected: boolean; demo: boolean; dryRun: boolean; countermeasures: boolean; kickAt: number | null; banAt: number | null; settingsAt: string | null };
  attention: { vision: number; backdoorsHigh: number; backdoorsTotal: number; integrations: number };
};

const ACTION_TONE = { ban: "red", kick: "red", screenshot: "amber", log: "neutral", none: "neutral" } as const;

function Tile({ label, value, sub, accent }: { label: string; value: string | number; sub?: string; accent?: "red" | "amber" | "green" }) {
  return (
    <div className="rounded-xl border border-line bg-panel px-4 py-3.5">
      <p className="text-xs text-muted">{label}</p>
      <p className={cx("mt-1.5 text-2xl font-semibold tabular-nums tracking-tight", accent === "red" && "text-red-300", accent === "amber" && "text-amber-200", accent === "green" && "text-emerald-300")}>{value}</p>
      {sub && <p className="mt-0.5 text-xs text-subtle">{sub}</p>}
    </div>
  );
}

function Card({ title, action, children, className }: { title: string; action?: React.ReactNode; children: React.ReactNode; className?: string }) {
  return (
    <section className={cx("rounded-xl border border-line bg-panel", className)}>
      <div className="flex items-center justify-between gap-3 border-b border-line px-4 py-3">
        <h2 className="text-sm font-medium">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

function Row({ label, value, tone }: { label: string; value: string; tone?: "ok" | "warn" | "bad" }) {
  return (
    <div className="flex items-center justify-between gap-3 px-4 py-2 text-sm">
      <span className="text-muted">{label}</span>
      <span className={cx("flex items-center gap-2 font-medium", tone === "ok" && "text-emerald-300", tone === "warn" && "text-amber-200", tone === "bad" && "text-red-300")}>
        {tone && <span className={cx("size-1.5 rounded-full", tone === "ok" ? "bg-emerald-400" : tone === "warn" ? "bg-amber-300" : "bg-red-400")} />}
        {value}
      </span>
    </div>
  );
}

export function Overview({ name }: { name: string }) {
  const [data, setData] = useState<Data | null>(null);
  const load = useCallback(async () => setData(await api<Data>("/api/overview")), []);
  useEffect(() => {
    load().catch(() => {});
    const t = setInterval(() => load().catch(() => {}), 10000);
    return () => clearInterval(t);
  }, [load]);

  if (!data) return <Empty>Loading…</Empty>;
  const { stats, day, server, attention } = data;
  const peak = Math.max(1, ...day.buckets);
  const topCodes = day.codes.slice(0, 6);
  const topMax = Math.max(1, ...topCodes.map((c) => c.count));
  const attentionItems = [
    attention.vision > 0 && { href: "/vision", text: `${attention.vision} capture(s) waiting for review`, tone: "amber" as const },
    attention.backdoorsHigh > 0 && { href: "/backdoors", text: `${attention.backdoorsHigh} high-severity backdoor finding(s)`, tone: "red" as const },
    attention.integrations > 0 && { href: "/settings", text: `${attention.integrations} resource(s) suggested by learning mode`, tone: "neutral" as const },
    server.dryRun && { href: "/settings", text: "Dry run is on: nobody is kicked or banned", tone: "amber" as const },
  ].filter(Boolean) as { href: string; text: string; tone: "amber" | "red" | "neutral" }[];

  return (
    <div className="space-y-5 px-4 py-5 sm:px-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-xs text-subtle">Welcome back, {name}</p>
          <h1 className="mt-0.5 text-xl font-semibold tracking-tight">Overview</h1>
        </div>
        <span className={cx("inline-flex h-7 items-center gap-2 rounded-full border px-3 text-xs", server.connected ? "border-emerald-900/70 bg-emerald-950/30 text-emerald-300" : "border-line-strong text-muted")}>
          <span className={cx("size-1.5 rounded-full", server.connected ? "animate-pulse bg-emerald-400" : "bg-zinc-500")} />
          {server.connected ? "Game server connected" : server.demo ? "Demo data (no game server)" : "Game server offline"}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Tile label="Players online" value={stats.online} sub={`${stats.tracked} seen in total`} />
        <Tile label="Detections, 24 h" value={stats.detections24h} sub={`${day.players} different player(s)`} accent={stats.detections24h > 0 ? "amber" : undefined} />
        <Tile label="Players kicked or banned, 24 h" value={stats.actions24h} accent={stats.actions24h > 0 ? "red" : undefined} />
        <Tile label="Active bans" value={stats.bans} sub={server.banAt ? `auto-ban at score ${server.banAt}` : undefined} />
      </div>

      <div className="grid gap-5 xl:grid-cols-3">
        <Card title="Detections, last 24 hours" className="xl:col-span-2" action={<Link href="/stats" className="text-xs text-muted hover:text-fg">All stats →</Link>}>
          <div className="px-4 pb-3 pt-4">
            <div className="flex h-32 items-end gap-1 sm:h-56" role="img" aria-label="Detections per hour, client and server">
              {day.buckets.map((n, i) => {
                const server = day.serverBuckets[i] ?? 0;
                return (
                  <div key={i} className="flex h-full flex-1 flex-col justify-end" title={`${n} detection(s), ${server} server-side`}>
                    <div className="w-full rounded-t-sm bg-slate-600/70" style={{ height: `${((n - server) / peak) * 100}%` }} />
                    <div className={cx("w-full bg-sky-400/80", server === n && "rounded-t-sm")} style={{ height: `${(server / peak) * 100}%` }} />
                    {n === 0 && <div className="h-px w-full bg-line" />}
                  </div>
                );
              })}
            </div>
            <div className="mt-2 flex items-center justify-between text-[11px] text-subtle">
              <span>24 h ago</span>
              <span className="flex items-center gap-3">
                <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-sky-400/80" />server evidence</span>
                <span className="flex items-center gap-1.5"><span className="size-2 rounded-sm bg-slate-600/70" />client scanner</span>
              </span>
              <span>now</span>
            </div>
          </div>
          <div className="border-t border-line px-4 py-3">
            <p className="mb-2 text-xs text-muted">Most frequent</p>
            {topCodes.length === 0 ? (
              <p className="text-xs text-subtle">Nothing detected in the last 24 hours.</p>
            ) : (
              <ul className="space-y-1.5">
                {topCodes.map((c) => (
                  <li key={c.code} className="flex items-center gap-3 text-xs">
                    <span className="w-44 shrink-0 truncate font-mono">{c.code}</span>
                    <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-elevated">
                      <span className="block h-full rounded-full bg-slate-400/80" style={{ width: `${(c.count / topMax) * 100}%` }} />
                    </span>
                    <span className="w-16 shrink-0 text-right tabular-nums text-muted">{c.count} · {c.players}p</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </Card>

        <div className="space-y-5">
          <Card title="Protection">
            <div className="divide-y divide-line">
              <Row label="Enforcement" value={server.dryRun ? "Dry run" : "Active"} tone={server.dryRun ? "warn" : "ok"} />
              <Row label="Countermeasures" value={server.countermeasures ? "Undo cheat effects" : "Off"} tone={server.countermeasures ? "ok" : "warn"} />
              <Row label="Kick / ban at score" value={server.kickAt && server.banAt ? `${server.kickAt} / ${server.banAt}` : "—"} />
              <Row label="Settings updated" value={server.settingsAt ? timeAgo(server.settingsAt) : "—"} />
            </div>
          </Card>
          <Card title="Needs attention">
            {attentionItems.length === 0 ? (
              <p className="px-4 py-3 text-sm text-muted">All clear.</p>
            ) : (
              <ul className="divide-y divide-line">
                {attentionItems.map((a) => (
                  <li key={a.text}>
                    <Link href={a.href} className="flex items-center gap-2.5 px-4 py-2.5 text-sm hover:bg-elevated/50">
                      <span className={cx("size-1.5 shrink-0 rounded-full", a.tone === "red" ? "bg-red-400" : a.tone === "amber" ? "bg-amber-300" : "bg-slate-400")} />
                      <span className="flex-1">{a.text}</span>
                      <span className="text-subtle">→</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card title="Highest scores online" action={<Link href="/players" className="text-xs text-muted hover:text-fg">Players →</Link>}>
            {data.top.length === 0 ? (
              <p className="px-4 py-3 text-sm text-muted">No online player has a score.</p>
            ) : (
              <ul className="divide-y divide-line">
                {data.top.map((p) => (
                  <li key={p.key} className="flex items-center gap-3 px-4 py-2 text-sm">
                    <span className="min-w-0 flex-1 truncate">{p.name} <span className="text-subtle">#{p.id}</span></span>
                    <span className={cx("font-mono tabular-nums", server.banAt && p.score >= server.banAt * 0.6 ? "text-red-300" : "text-muted")}>{p.score.toFixed(0)}</span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      </div>

      <div className="grid gap-5 xl:grid-cols-3">
        <Card title="Latest detections" className="xl:col-span-2" action={<Link href="/live" className="text-xs text-muted hover:text-fg">Live feed →</Link>}>
          {data.recent.length === 0 ? (
            <Empty>No detections yet.</Empty>
          ) : (
            <ul className="divide-y divide-line">
              {data.recent.map((d) => (
                <li key={d.id} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-2.5 text-sm">
                  <Badge tone={ACTION_TONE[d.action] ?? "neutral"}>{d.code}</Badge>
                  <span className="min-w-0 flex-1 truncate">{d.name} <span className="text-subtle">#{d.player}</span></span>
                  <span className="text-xs text-subtle">{d.source}</span>
                  <span className="w-16 text-right font-mono text-xs tabular-nums text-muted">+{d.severity} → {d.score.toFixed(0)}</span>
                  <span className="w-14 text-right text-xs text-subtle">{timeAgo(d.at)}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
        <Card title="Recent bans" action={<Link href="/bans" className="text-xs text-muted hover:text-fg">Bans →</Link>}>
          {data.bans.length === 0 ? (
            <p className="px-4 py-3 text-sm text-muted">No bans.</p>
          ) : (
            <ul className="divide-y divide-line">
              {data.bans.map((b) => (
                <li key={b.id} className="px-4 py-2.5">
                  <div className="flex items-center gap-2 text-sm">
                    <span className="min-w-0 flex-1 truncate font-medium">{b.name}</span>
                    <span className="text-xs text-subtle">{timeAgo(b.createdAt)}</span>
                  </div>
                  <p className="mt-0.5 truncate text-xs text-muted">{b.reason}</p>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
