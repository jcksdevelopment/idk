"use client";

import { useCallback, useEffect, useState } from "react";
import { api, postAction } from "@/lib/client";
import type { Ban, Page } from "@/lib/types";
import { SearchIcon } from "./icons";
import { Badge, Button, Dialog, Empty, Input, Pagination, timeAgo, useDebounced } from "./ui";

function expiry(b: Ban) {
  if (!b.expiresAt) return <Badge tone="red">permanent</Badge>;
  const left = Date.parse(b.expiresAt) - Date.now();
  if (left <= 0) return <Badge tone="neutral">expired</Badge>;
  return <Badge tone="amber">{timeAgo(b.expiresAt)}</Badge>;
}

export function BansTable() {
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Page<Ban> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<Ban | null>(null);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const query = useDebounced(q);

  const load = useCallback(async () => {
    try {
      setData(await api<Page<Ban>>(`/api/bans?${new URLSearchParams({ q: query, page: String(page), pageSize: "20" })}`));
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [query, page]);

  useEffect(() => {
    load();
    const t = setInterval(load, 10000);
    return () => clearInterval(t);
  }, [load]);
  useEffect(() => setPage(1), [query]);

  async function unban() {
    if (!confirm) return;
    setBusy(true);
    setActionError(null);
    try {
      await postAction({ type: "unban", banId: confirm.id });
      setConfirm(null);
      load();
      setTimeout(load, 1500);
    } catch (e) {
      setActionError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="px-6 py-4">
        <div className="relative w-full max-w-sm">
          <SearchIcon className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-subtle" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search ban ID, name, reason, identifier" className="pl-9" aria-label="Search bans" />
        </div>
      </div>

      <div className="mx-6 mb-6 overflow-hidden rounded-lg border border-line">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-sm">
            <thead>
              <tr className="border-b border-line text-left text-xs text-subtle">
                <th className="px-4 py-2.5 font-medium">Ban ID</th>
                <th className="px-4 py-2.5 font-medium">Player</th>
                <th className="px-4 py-2.5 font-medium">Reason</th>
                <th className="px-4 py-2.5 font-medium">By</th>
                <th className="px-4 py-2.5 font-medium">Issued</th>
                <th className="px-4 py-2.5 font-medium">Expires</th>
                <th className="px-4 py-2.5" />
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {data?.items.map((b) => (
                <tr key={b.id} className="group hover:bg-elevated/50">
                  <td className="px-4 py-2.5 font-mono text-xs text-muted">{b.id}</td>
                  <td className="px-4 py-2.5">
                    {b.name}
                    <p className="mt-0.5 font-mono text-[11px] text-subtle">{b.identifiers.length} identifiers</p>
                  </td>
                  <td className="max-w-[280px] px-4 py-2.5">
                    <p className="truncate text-muted" title={b.reason}>{b.reason}</p>
                    {b.code && <p className="mt-0.5 font-mono text-[11px] text-subtle">{b.code}</p>}
                  </td>
                  <td className="px-4 py-2.5 text-muted">{b.bannedBy}</td>
                  <td className="px-4 py-2.5 text-muted">{timeAgo(b.createdAt)}</td>
                  <td className="px-4 py-2.5">{expiry(b)}</td>
                  <td className="px-4 py-2.5 text-right">
                    {b.pendingUnban ? (
                      <span className="text-xs text-subtle">Unban pending…</span>
                    ) : (
                      <Button size="sm" variant="ghost" className="opacity-60 group-hover:opacity-100 focus:opacity-100" onClick={() => setConfirm(b)}>
                        Unban
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {data && data.items.length === 0 && <Empty>{query ? `No bans match “${query}”.` : "No bans."}</Empty>}
        {!data && !error && <Empty>Loading…</Empty>}
        {error && <Empty>Couldn&apos;t load bans: {error}</Empty>}
        {data && data.total > 0 && <Pagination page={data.page} pages={data.pages} total={data.total} onPage={setPage} />}
      </div>

      <Dialog open={!!confirm} onClose={() => { setConfirm(null); setActionError(null); }} title="Lift ban">
        <div className="space-y-4 px-5 py-4 text-sm">
          <p className="text-muted">
            Unban <span className="text-fg">{confirm?.name}</span> (<span className="font-mono">{confirm?.id}</span>)? The game server removes the ban on its next poll; all {confirm?.identifiers.length} linked identifiers are released.
          </p>
          {actionError && <p className="text-red-400">{actionError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button variant="primary" disabled={busy} onClick={unban}>{busy ? "Sending…" : "Unban"}</Button>
          </div>
        </div>
      </Dialog>
    </>
  );
}
