"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { DetectionStats } from "@/lib/types";
import { Badge, Button, Empty, timeAgo } from "./ui";

const RANGES = [
  { hours: 1, label: "1 h" },
  { hours: 24, label: "24 h" },
  { hours: 168, label: "7 d" },
  { hours: 720, label: "30 d" },
];

function hint(c: DetectionStats["codes"][number], totalPlayers: number) {
  if (c.players >= 5 && c.players >= totalPlayers * 0.3 && c.server === 0) return "Many different players, client-side only: check for a false positive";
  if (c.bypass > 0 && c.bypass === c.count) return "Only staff with bypass";
  return null;
}

export function StatsView() {
  const [hours, setHours] = useState(24);
  const [data, setData] = useState<DetectionStats | null>(null);

  const load = useCallback(async () => setData(await api<DetectionStats>(`/api/stats?hours=${hours}`)), [hours]);
  useEffect(() => {
    load().catch(() => {});
    const t = setInterval(() => load().catch(() => {}), 15000);
    return () => clearInterval(t);
  }, [load]);

  if (!data) return <Empty>Loading…</Empty>;
  const peak = Math.max(1, ...data.buckets);

  return (
    <div className="space-y-4 px-6 pb-6">
      <div className="flex flex-wrap items-center gap-2">
        {RANGES.map((r) => (
          <Button key={r.hours} size="sm" variant={r.hours === hours ? "primary" : "ghost"} onClick={() => setHours(r.hours)}>{r.label}</Button>
        ))}
        <span className="ml-auto text-xs text-muted">{data.total} detection(s) · {data.players} player(s)</span>
      </div>

      <div className="rounded-lg border border-line bg-panel px-4 pb-3 pt-4">
        <div className="flex h-24 items-end gap-1" role="img" aria-label="Detections over time">
          {data.buckets.map((n, i) => (
            <div key={i} className="flex-1 rounded-sm bg-slate-500/70" style={{ height: `${Math.max(n ? 4 : 1, (n / peak) * 100)}%`, opacity: n ? 1 : 0.25 }} title={`${n}`} />
          ))}
        </div>
        <div className="mt-1 flex justify-between font-mono text-[10px] text-subtle">
          <span>-{data.hours >= 48 ? `${data.hours / 24} d` : `${data.hours} h`}</span>
          <span>now</span>
        </div>
      </div>

      <div className="overflow-x-auto rounded-lg border border-line">
        {data.codes.length === 0 ? (
          <Empty>No detections in this range.</Empty>
        ) : (
          <table className="w-full min-w-[720px] text-sm">
            <thead className="text-left text-xs text-subtle">
              <tr className="border-b border-line">
                <th className="px-4 py-2 font-medium">Code</th>
                <th className="px-2 py-2 text-right font-medium">Hits</th>
                <th className="px-2 py-2 text-right font-medium">Players</th>
                <th className="px-2 py-2 text-right font-medium">Client / server</th>
                <th className="px-2 py-2 text-right font-medium">Kicks</th>
                <th className="px-2 py-2 text-right font-medium">Bans</th>
                <th className="px-4 py-2 font-medium">Last</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {data.codes.map((c) => {
                const h = hint(c, data.players);
                return (
                  <tr key={c.code}>
                    <td className="px-4 py-2">
                      <span className="font-mono text-xs">{c.code}</span>
                      {h && <span className="ml-2"><Badge tone="amber">{h}</Badge></span>}
                    </td>
                    <td className="px-2 py-2 text-right tabular-nums">{c.count}</td>
                    <td className="px-2 py-2 text-right tabular-nums">{c.players}</td>
                    <td className="px-2 py-2 text-right tabular-nums text-muted">{c.client} / {c.server}</td>
                    <td className="px-2 py-2 text-right tabular-nums">{c.kicks}</td>
                    <td className="px-2 py-2 text-right tabular-nums">{c.bans}</td>
                    <td className="px-4 py-2 text-xs text-muted">{timeAgo(c.lastAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
      <p className="text-xs text-subtle">
        A code that many different players trigger, and only the client reports, is more likely a false positive than a cheat. Raise its threshold in Settings, add it to scoring.logOnly, or trust the resource causing it.
      </p>
    </div>
  );
}
