"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { Detection, Page, Player } from "@/lib/types";
import { SearchIcon } from "./icons";
import { ActionDialog, type PendingAction } from "./action-dialog";
import { Badge, Button, cx, Dialog, Empty, Input, Pagination, timeAgo, useDebounced } from "./ui";

function scoreTone(score: number) {
  return score >= 80 ? "red" : score >= 40 ? "amber" : score > 0 ? "slate" : "neutral";
}

export function PlayersTable() {
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<"all" | "online">("online");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Page<Player> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState<PendingAction>(null);
  const [detail, setDetail] = useState<Player | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const query = useDebounced(q);

  const load = useCallback(async () => {
    try {
      const params = new URLSearchParams({ q: query, page: String(page), pageSize: "20", status });
      setData(await api<Page<Player>>(`/api/players?${params}`));
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [query, page, status]);

  useEffect(() => {
    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, [load]);

  useEffect(() => setPage(1), [query, status]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(t);
  }, [toast]);

  return (
    <>
      <div className="flex flex-wrap items-center gap-2 px-6 py-4">
        <div className="relative w-full max-w-sm">
          <SearchIcon className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-subtle" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, server ID or identifier" className="pl-9" aria-label="Search players" />
        </div>
        <div className="flex rounded-md border border-line-strong p-0.5 text-xs" role="tablist">
          {(["online", "all"] as const).map((s) => (
            <button
              key={s}
              role="tab"
              aria-selected={status === s}
              onClick={() => setStatus(s)}
              className={cx("h-7 rounded px-3 capitalize", status === s ? "bg-elevated text-fg" : "text-muted hover:text-fg")}
            >
              {s === "online" ? "Online" : "All tracked"}
            </button>
          ))}
        </div>
      </div>

      <div className="mx-6 mb-6 overflow-hidden rounded-lg border border-line">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs text-subtle">
                <th className="px-4 py-2.5 font-medium">ID</th>
                <th className="px-4 py-2.5 font-medium">Player</th>
                <th className="px-4 py-2.5 font-medium">Score</th>
                <th className="px-4 py-2.5 font-medium">Detections</th>
                <th className="px-4 py-2.5 font-medium">Heartbeat</th>
                <th className="px-4 py-2.5 font-medium">Ping</th>
                <th className="px-4 py-2.5 font-medium">Last seen</th>
                <th className="px-4 py-2.5" />
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {data?.items.map((p) => (
                <tr key={p.key} className="group hover:bg-elevated/50">
                  <td className="px-4 py-2.5 font-mono text-xs text-subtle tabular-nums">{p.id}</td>
                  <td className="px-4 py-2.5">
                    <button onClick={() => setDetail(p)} className="flex items-center gap-2 text-left hover:underline">
                      <span className={cx("size-1.5 rounded-full", p.online ? "bg-emerald-400" : "bg-zinc-700")} aria-label={p.online ? "online" : "offline"} />
                      {p.name}
                    </button>
                    <p className="mt-0.5 truncate pl-3.5 font-mono text-[11px] text-subtle">{p.identifiers.find((i) => i.startsWith("discord:")) ?? p.identifiers[0] ?? "—"}</p>
                  </td>
                  <td className="px-4 py-2.5">
                    <Badge tone={scoreTone(p.score)}>{p.score.toFixed(0)}</Badge>
                  </td>
                  <td className="px-4 py-2.5 tabular-nums text-muted">{p.detections}</td>
                  <td className="px-4 py-2.5 font-mono text-xs text-muted">
                    {p.heartbeat ? (
                      <>
                        seq {p.heartbeat.seq}
                        {p.heartbeat.failures > 0 && <span className="ml-1.5 text-red-400">{p.heartbeat.failures} fail</span>}
                      </>
                    ) : (
                      <span className="text-subtle">—</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 tabular-nums text-muted">{p.online ? `${p.ping} ms` : "—"}</td>
                  <td className="px-4 py-2.5 text-muted">{p.online ? "now" : timeAgo(p.lastSeen)}</td>
                  <td className="px-4 py-2.5">
                    <div className="flex justify-end gap-1 opacity-60 transition-opacity group-hover:opacity-100 focus-within:opacity-100">
                      <Button size="sm" variant="ghost" disabled={!p.online} onClick={() => setAction({ type: "screenshot", player: p.id, serverId: p.serverId, name: p.name })}>
                        Capture
                      </Button>
                      <Button size="sm" variant="ghost" disabled={!p.online} onClick={() => setAction({ type: "kick", player: p.id, serverId: p.serverId, name: p.name })}>
                        Kick
                      </Button>
                      <Button size="sm" variant="ghost" className="hover:text-red-300" onClick={() => setAction({ type: "ban", player: p.id, serverId: p.serverId, name: p.name })}>
                        Ban
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {data && data.items.length === 0 && <Empty>{query ? `No players match “${query}”.` : status === "online" ? "Nobody is online." : "No players tracked yet."}</Empty>}
        {!data && !error && <Empty>Loading…</Empty>}
        {error && <Empty>Couldn&apos;t load players: {error}</Empty>}
        {data && data.total > 0 && <Pagination page={data.page} pages={data.pages} total={data.total} onPage={setPage} />}
      </div>

      <ActionDialog action={action} onClose={() => setAction(null)} onDone={(m) => { setToast(m); setTimeout(load, 1200); }} />
      <PlayerDetail player={detail} onClose={() => setDetail(null)} />
      {toast && (
        <div role="status" className="fixed right-6 bottom-6 rounded-md border border-line-strong bg-panel px-4 py-3 text-sm shadow-lg">
          {toast}
        </div>
      )}
    </>
  );
}

function PlayerDetail({ player, onClose }: { player: Player | null; onClose: () => void }) {
  const [items, setItems] = useState<Detection[] | null>(null);
  useEffect(() => {
    if (!player) return;
    setItems(null);
    api<{ items: Detection[] }>(`/api/detections?player=${encodeURIComponent(player.key)}&limit=50`).then((r) => setItems(r.items), () => setItems([]));
  }, [player]);

  return (
    <Dialog open={!!player} onClose={onClose} title={player ? `${player.name} · #${player.id}` : ""} wide>
      {player && (
        <div className="grid gap-0 md:grid-cols-[240px_1fr]">
          <dl className="space-y-3 border-line px-5 py-4 text-sm md:border-r">
            <div>
              <dt className="text-xs text-subtle">Status</dt>
              <dd>{player.online ? "Online" : `Offline · ${timeAgo(player.lastSeen)}`}</dd>
            </div>
            <div>
              <dt className="text-xs text-subtle">Suspicion score</dt>
              <dd className="tabular-nums">{player.score.toFixed(1)}</dd>
            </div>
            <div>
              <dt className="text-xs text-subtle">First seen</dt>
              <dd>{timeAgo(player.firstSeen)}</dd>
            </div>
            <div>
              <dt className="text-xs text-subtle">Identifiers</dt>
              <dd className="mt-1 space-y-1">
                {player.identifiers.map((i) => (
                  <p key={i} className="truncate font-mono text-[11px] text-muted" title={i}>{i}</p>
                ))}
              </dd>
            </div>
          </dl>
          <div className="scroll-quiet max-h-[60vh] overflow-y-auto">
            {items === null && <Empty>Loading…</Empty>}
            {items?.length === 0 && <Empty>No detections recorded.</Empty>}
            <ul className="divide-y divide-line">
              {items?.map((d) => (
                <li key={d.id} className="px-5 py-3">
                  <div className="flex items-center gap-2">
                    <Badge tone={d.action === "ban" || d.action === "kick" ? "red" : d.severity >= 30 ? "amber" : "neutral"}>{d.code}</Badge>
                    <span className="text-xs text-subtle">{d.source}</span>
                    <span className="ml-auto text-xs text-subtle">{timeAgo(d.at)}</span>
                  </div>
                  <p className="mt-1.5 font-mono text-[11px] text-muted">
                    sev {d.severity} · score {d.score.toFixed(0)} · {d.action} · {JSON.stringify(d.evidence)}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </Dialog>
  );
}
