"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { BackdoorFinding, BackdoorScan } from "@/lib/types";
import { Badge, Button, Dialog, Empty, timeAgo } from "./ui";

type Response = { scan: BackdoorScan | null; connected: boolean; canAct: boolean };
type Pending = { action: "remove" | "quarantine" | "ignore"; finding: BackdoorFinding } | null;

const TONE = { high: "red", medium: "amber", low: "neutral" } as const;
const ACTION_TEXT = {
  remove: "Delete the flagged line from the file. A backup is kept next to it as .jac-bak; restart the resource afterwards.",
  quarantine: "Move the whole file into the resource's .jac-quarantine folder so it can't load. The resource may fail to start until you fix it.",
  ignore: "Mark this finding as reviewed. It is saved in backdoorScanner.ignoreIds and won't be reported again.",
};

export function BackdoorTable() {
  const [data, setData] = useState<Response | null>(null);
  const [pending, setPending] = useState<Pending>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = useCallback(async () => setData(await api<Response>("/api/backdoors?serverId=main")), []);
  useEffect(() => {
    load().catch(() => {});
    const t = setInterval(() => load().catch(() => {}), 8000);
    return () => clearInterval(t);
  }, [load]);

  async function act(action: string, id?: string) {
    try {
      const r = await api<{ connected: boolean }>("/api/backdoors", { method: "POST", body: JSON.stringify({ serverId: "main", action, id }) });
      setMessage(r.connected ? `${action} sent to the game server.` : `${action} queued; the game server picks it up when it connects.`);
      setPending(null);
    } catch (e) {
      setMessage((e as Error).message);
    }
  }

  if (!data) return <Empty>Loading…</Empty>;
  const findings = data.scan?.findings ?? [];

  return (
    <>
      <div className="flex flex-wrap items-center gap-3 px-6 py-4 text-xs text-muted">
        <span>{data.scan ? `Last scan ${timeAgo(data.scan.at)} · ${findings.length} finding(s)` : "No scan received yet."}</span>
        {data.canAct && <Button size="sm" variant="secondary" onClick={() => act("scan")}>Rescan now</Button>}
        {message && <span className="text-slate-300">{message}</span>}
      </div>
      <div className="mx-6 mb-6 overflow-hidden rounded-lg border border-line">
        {findings.length === 0 ? (
          <Empty>{data.scan ? "No findings. Every resource passed the scan." : "Findings appear here after the game server scans on start or on 'jac scan'."}</Empty>
        ) : (
          <ul className="divide-y divide-line">
            {findings.map((f) => (
              <li key={f.id} className="px-4 py-3">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge tone={TONE[f.severity]}>{f.severity}</Badge>
                  <span className="font-mono text-xs text-slate-400">{f.rule}</span>
                  <span className="text-sm">{f.resource}/{f.file}:{f.line}</span>
                  <span className="font-mono text-[11px] text-subtle">{f.id}</span>
                  {data.canAct && (
                    <span className="ml-auto flex gap-1">
                      <Button size="sm" variant="ghost" onClick={() => setPending({ action: "ignore", finding: f })}>Ignore</Button>
                      <Button size="sm" variant="ghost" onClick={() => setPending({ action: "quarantine", finding: f })}>Quarantine</Button>
                      <Button size="sm" variant="danger" onClick={() => setPending({ action: "remove", finding: f })}>Remove line</Button>
                    </span>
                  )}
                </div>
                <p className="mt-1 text-xs text-muted">{f.description}</p>
                <pre className="scroll-quiet mt-2 overflow-x-auto rounded bg-[#070708] px-3 py-2 font-mono text-[11px] text-zinc-300">{f.snippet}</pre>
              </li>
            ))}
          </ul>
        )}
      </div>
      <Dialog open={!!pending} onClose={() => setPending(null)} title={pending ? `${pending.action} ${pending.finding.id}` : ""}>
        {pending && (
          <div className="space-y-4 px-5 py-4 text-sm">
            <p className="font-mono text-xs text-muted">{pending.finding.resource}/{pending.finding.file}:{pending.finding.line}</p>
            <p className="text-muted">{ACTION_TEXT[pending.action]}</p>
            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => setPending(null)}>Cancel</Button>
              <Button variant={pending.action === "ignore" ? "primary" : "danger"} onClick={() => act(pending.action, pending.finding.id)}>Confirm</Button>
            </div>
          </div>
        )}
      </Dialog>
    </>
  );
}
