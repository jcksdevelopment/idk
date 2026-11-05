"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/client";
import type { IntegrationSuggestions as Data } from "@/lib/types";
import { Badge, Button, Dialog, timeAgo } from "./ui";

type Response = { data: Data | null; connected: boolean; canAct: boolean };

export function IntegrationSuggestions() {
  const [res, setRes] = useState<Response | null>(null);
  const [confirm, setConfirm] = useState<"apply" | "clear" | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = useCallback(async () => setRes(await api<Response>("/api/integrations?serverId=main")), []);
  useEffect(() => {
    load().catch(() => {});
    const t = setInterval(() => load().catch(() => {}), 10000);
    return () => clearInterval(t);
  }, [load]);

  async function act(action: "apply" | "clear") {
    try {
      const r = await api<{ connected: boolean }>("/api/integrations", { method: "POST", body: JSON.stringify({ serverId: "main", action }) });
      setMessage(r.connected ? `${action} sent to the game server.` : `${action} queued; the game server picks it up when it connects.`);
    } catch (e) {
      setMessage((e as Error).message);
    }
    setConfirm(null);
  }

  const data = res?.data;
  if (!data || (!data.learning && data.suggestions.length === 0)) return null;
  const list = data.suggestions;

  return (
    <section className="mx-6 mt-4 rounded-lg border border-line bg-panel">
      <div className="flex flex-wrap items-center gap-3 px-4 py-3">
        <h2 className="text-sm font-medium">Learning mode suggestions</h2>
        <span className="text-xs text-subtle">updated {timeAgo(data.at)}</span>
        {message && <span className="text-xs text-slate-300">{message}</span>}
        {res?.canAct && list.length > 0 && (
          <span className="ml-auto flex gap-2">
            <Button size="sm" variant="ghost" onClick={() => setConfirm("clear")}>Clear data</Button>
            <Button size="sm" variant="primary" onClick={() => setConfirm("apply")}>Trust all listed</Button>
          </span>
        )}
      </div>
      {list.length === 0 ? (
        <p className="border-t border-line px-4 py-3 text-xs text-muted">No suggestions yet. Resources that use trusted behaviours they aren&apos;t allowed appear here after a few uses.</p>
      ) : (
        <ul className="divide-y divide-line border-t border-line">
          {list.map((s) => (
            <li key={s.resource} className="flex flex-wrap items-center gap-2 px-4 py-2">
              <span className="font-mono text-xs">{s.resource}</span>
              {s.behaviours.map((b) => <Badge key={b}>{b}</Badge>)}
            </li>
          ))}
        </ul>
      )}
      <Dialog open={!!confirm} onClose={() => setConfirm(null)} title={confirm === "apply" ? "Trust listed resources" : "Clear learning data"}>
        <div className="space-y-4 px-5 py-4 text-sm">
          <p className="text-muted">
            {confirm === "apply"
              ? "Adds every listed resource and behaviour to integrations.resources and saves config.json. Only do this if you recognise each resource; a cheat menu injected into a fake resource name would be trusted too."
              : "Forgets everything learning mode has counted so far. Nothing in the settings changes."}
          </p>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button variant={confirm === "apply" ? "primary" : "danger"} onClick={() => confirm && act(confirm)}>{confirm === "apply" ? "Trust" : "Clear"}</Button>
          </div>
        </div>
      </Dialog>
    </section>
  );
}
