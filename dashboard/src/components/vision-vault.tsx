"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { VisionCapture } from "@/lib/types";
import { ActionDialog, type PendingAction } from "./action-dialog";
import { Badge, Button, cx, Dialog, Empty, timeAgo } from "./ui";

type Filter = "pending" | "cheat" | "all";

const VERDICT_TONE = { cheat: "red", suspicious: "amber", clean: "green", error: "neutral" } as const;

export function VisionVault() {
  const [filter, setFilter] = useState<Filter>("pending");
  const [items, setItems] = useState<VisionCapture[] | null>(null);
  const [open, setOpen] = useState<VisionCapture | null>(null);
  const [action, setAction] = useState<PendingAction>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setItems((await api<{ items: VisionCapture[] }>(`/api/vision?filter=${filter}`)).items);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [filter]);

  useEffect(() => {
    setItems(null);
    load();
    const t = setInterval(load, 10000);
    return () => clearInterval(t);
  }, [load]);

  async function review(c: VisionCapture, verdict: "confirmed" | "dismissed") {
    try {
      await api(`/api/vision/${c.id}/review`, { method: "POST", body: JSON.stringify({ review: verdict }) });
      setOpen(null);
      load();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <>
      <div className="flex items-center gap-2 px-6 py-4">
        <div className="flex rounded-md border border-line-strong p-0.5 text-xs" role="tablist">
          {([["pending", "Awaiting review"], ["cheat", "Flagged as cheat"], ["all", "All captures"]] as const).map(([f, label]) => (
            <button key={f} role="tab" aria-selected={filter === f} onClick={() => setFilter(f)} className={cx("h-7 rounded px-3", filter === f ? "bg-elevated text-fg" : "text-muted hover:text-fg")}>
              {label}
            </button>
          ))}
        </div>
        {error && <p className="text-sm text-red-400">{error}</p>}
      </div>

      {items === null && <Empty>Loading…</Empty>}
      {items?.length === 0 && <Empty>{filter === "pending" ? "Nothing waiting for review." : "No captures yet."}</Empty>}

      <div className="grid gap-4 px-6 pb-8 sm:grid-cols-2 xl:grid-cols-3">
        {items?.map((c) => (
          <button key={c.id} onClick={() => setOpen(c)} className="group overflow-hidden rounded-lg border border-line text-left transition-colors hover:border-line-strong">
            <div className="relative aspect-video bg-black">
              <Capture id={c.id} name={c.name} className="size-full object-cover opacity-90 transition-opacity group-hover:opacity-100" />
              <div className="absolute top-2 left-2 flex gap-1.5">
                <Badge tone={VERDICT_TONE[c.verdict.verdict]} className="bg-black/70">{c.verdict.verdict}</Badge>
                {c.verdict.verdict !== "error" && <Badge className="bg-black/70">{Math.round(c.verdict.confidence * 100)}%</Badge>}
              </div>
              {c.review !== "pending" && (
                <Badge tone={c.review === "confirmed" ? "red" : "neutral"} className="absolute top-2 right-2 bg-black/70">{c.review}</Badge>
              )}
            </div>
            <div className="space-y-1 px-4 py-3">
              <div className="flex items-center justify-between gap-2">
                <p className="truncate text-sm font-medium">{c.name} <span className="font-mono text-xs text-subtle">#{c.player}</span></p>
                <span className="shrink-0 text-xs text-subtle">{timeAgo(c.at)}</span>
              </div>
              <p className="line-clamp-2 text-xs text-muted">{c.verdict.error ?? c.verdict.summary}</p>
            </div>
          </button>
        ))}
      </div>

      <Dialog open={!!open} onClose={() => setOpen(null)} title={open ? `${open.name} · #${open.player}` : ""} wide>
        {open && (
          <div className="grid md:grid-cols-[1fr_280px]">
            <div className="bg-black">
              <Capture id={open.id} name={open.name} className="w-full" />
            </div>
            <div className="flex flex-col gap-4 border-line px-5 py-4 text-sm md:border-l">
              <div className="flex items-center gap-2">
                <Badge tone={VERDICT_TONE[open.verdict.verdict]}>{open.verdict.verdict}</Badge>
                {open.verdict.verdict !== "error" && (
                  <div className="flex flex-1 items-center gap-2">
                    <div className="h-1 flex-1 overflow-hidden rounded bg-line-strong">
                      <div className="h-full bg-zinc-300" style={{ width: `${open.verdict.confidence * 100}%` }} />
                    </div>
                    <span className="font-mono text-xs text-muted tabular-nums">{Math.round(open.verdict.confidence * 100)}%</span>
                  </div>
                )}
              </div>
              <p className="text-muted">{open.verdict.error ?? open.verdict.summary}</p>
              {open.verdict.findings.length > 0 && (
                <div>
                  <p className="mb-1.5 text-xs text-subtle">Findings</p>
                  <ul className="space-y-2">
                    {open.verdict.findings.map((f, i) => (
                      <li key={i} className="text-xs">
                        <span className="font-mono text-slate-400">{f.type}</span>
                        <p className="mt-0.5 text-muted">{f.description}</p>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              <dl className="space-y-1 text-xs text-subtle">
                <div className="flex justify-between gap-2"><dt>Trigger</dt><dd className="truncate text-right text-muted">{open.reason}</dd></div>
                <div className="flex justify-between gap-2"><dt>Model</dt><dd className="font-mono text-muted">{open.verdict.model || "—"}</dd></div>
                <div className="flex justify-between gap-2"><dt>Captured</dt><dd className="text-muted">{new Date(open.at).toLocaleString()}</dd></div>
                {open.reviewedBy && <div className="flex justify-between gap-2"><dt>Reviewed by</dt><dd className="text-muted">{open.reviewedBy}</dd></div>}
              </dl>
              <p className="text-xs leading-relaxed text-subtle">AI verdicts are advisory. JCKS Anticheat never bans on a vision verdict alone.</p>
              <div className="mt-auto flex flex-wrap gap-2 pt-2">
                <Button size="sm" variant="ghost" onClick={() => review(open, "dismissed")}>Dismiss</Button>
                <Button size="sm" variant="secondary" onClick={() => review(open, "confirmed")}>Confirm</Button>
                <Button
                  size="sm"
                  variant="danger"
                  onClick={() => {
                    review(open, "confirmed");
                    setAction({ type: "ban", player: open.player, serverId: open.serverId, name: open.name });
                  }}
                >
                  Confirm and ban
                </Button>
              </div>
            </div>
          </div>
        )}
      </Dialog>

      <ActionDialog action={action} onClose={() => setAction(null)} onDone={() => load()} />
    </>
  );
}

/** Capture image with a fallback: client-supplied JPEGs can be truncated or corrupt. */
function Capture({ id, name, className }: { id: string; name: string; className?: string }) {
  const [failed, setFailed] = useState(false);
  if (failed) {
    return <div className="grid aspect-video w-full place-items-center text-xs text-subtle">Image unavailable</div>;
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={`/api/vision/${id}/image`} alt={`Capture of ${name}`} loading="lazy" onError={() => setFailed(true)} className={className} />;
}
