"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { LogLevel, LogLine } from "@/lib/types";
import { Button, cx, Input } from "./ui";

type Stats = { online: number; tracked: number; detections24h: number; actions24h: number; bans: number; pendingReview: number };

const LEVEL_STYLE: Record<LogLevel, string> = {
  debug: "text-subtle",
  info: "text-zinc-300",
  warn: "text-amber-300",
  error: "text-red-400",
  crit: "text-red-300 font-medium",
};
const LEVEL_RANK: Record<LogLevel, number> = { debug: 0, info: 1, warn: 2, error: 3, crit: 4 };
const MAX_LINES = 1000;

export function LiveTerminal({ initialStats }: { initialStats: Stats }) {
  const [lines, setLines] = useState<LogLine[]>([]);
  const [stats, setStats] = useState(initialStats);
  const [status, setStatus] = useState<"connecting" | "live" | "reconnecting">("connecting");
  const [paused, setPaused] = useState(false);
  const [minLevel, setMinLevel] = useState<LogLevel>("debug");
  const [filter, setFilter] = useState("");
  const buffered = useRef<LogLine[]>([]);
  const pausedRef = useRef(paused);
  const scroller = useRef<HTMLDivElement>(null);
  const stick = useRef(true);

  pausedRef.current = paused;

  useEffect(() => {
    const es = new EventSource("/api/stream");
    const append = (incoming: LogLine[]) =>
      setLines((prev) => {
        const next = prev.concat(incoming);
        return next.length > MAX_LINES ? next.slice(next.length - MAX_LINES) : next;
      });
    es.addEventListener("open", () => setStatus("live"));
    es.addEventListener("error", () => setStatus("reconnecting"));
    es.addEventListener("backlog", (e) => setLines(JSON.parse((e as MessageEvent).data)));
    es.addEventListener("stats", (e) => setStats(JSON.parse((e as MessageEvent).data)));
    es.addEventListener("log", (e) => {
      const line = JSON.parse((e as MessageEvent).data) as LogLine;
      if (pausedRef.current) buffered.current.push(line);
      else append([line]);
    });
    return () => es.close();
  }, []);

  useEffect(() => {
    if (!paused && buffered.current.length) {
      const flush = buffered.current;
      buffered.current = [];
      setLines((prev) => prev.concat(flush).slice(-MAX_LINES));
    }
  }, [paused]);

  const visible = useMemo(() => {
    const q = filter.trim().toLowerCase();
    return lines.filter((l) => LEVEL_RANK[l.level] >= LEVEL_RANK[minLevel] && (!q || l.text.toLowerCase().includes(q) || l.kind.includes(q)));
  }, [lines, minLevel, filter]);

  useEffect(() => {
    const el = scroller.current;
    if (el && stick.current) el.scrollTop = el.scrollHeight;
  }, [visible]);

  const tiles: [string, number | string][] = [
    ["Online", stats.online],
    ["Detections · 24h", stats.detections24h],
    ["Kicked or banned · 24h", stats.actions24h],
    ["Active bans", stats.bans],
    ["Awaiting review", stats.pendingReview],
  ];

  return (
    <div className="flex flex-col md:h-dvh">
      <div className="grid grid-cols-2 border-b border-line sm:grid-cols-5">
        {tiles.map(([label, value]) => (
          <div key={label} className="border-line px-6 py-4 not-last:border-r max-sm:not-last:border-b">
            <p className="text-xs text-subtle">{label}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums tracking-tight">{value.toLocaleString()}</p>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-2 border-b border-line px-4 py-2.5">
        <span className="flex items-center gap-2 pr-2 text-xs text-muted">
          <span className={cx("size-1.5 rounded-full", status === "live" ? (paused ? "bg-amber-400" : "bg-emerald-400") : "bg-zinc-600")} />
          {status === "live" ? (paused ? `Paused · ${buffered.current.length} buffered` : "Live") : status === "connecting" ? "Connecting" : "Reconnecting"}
        </span>
        <Input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="Filter by player, code, text…" className="h-8 max-w-xs text-xs" aria-label="Filter log" />
        <select
          value={minLevel}
          onChange={(e) => setMinLevel(e.target.value as LogLevel)}
          aria-label="Minimum level"
          className="h-8 rounded-md border border-line-strong bg-bg px-2 text-xs text-muted"
        >
          <option value="debug">All levels</option>
          <option value="info">Info and above</option>
          <option value="warn">Warnings and above</option>
          <option value="error">Errors only</option>
        </select>
        <div className="ml-auto flex gap-2">
          <Button size="sm" variant="secondary" onClick={() => setPaused((p) => !p)}>
            {paused ? "Resume" : "Pause"}
          </Button>
          <Button size="sm" variant="ghost" onClick={() => setLines([])}>
            Clear
          </Button>
        </div>
      </div>

      <div
        ref={scroller}
        onScroll={(e) => {
          const el = e.currentTarget;
          stick.current = el.scrollHeight - el.scrollTop - el.clientHeight < 40;
        }}
        className="scroll-quiet min-h-[360px] flex-1 overflow-y-auto bg-[#070708] px-4 py-3 font-mono text-[12px] leading-[1.7]"
        role="log"
        aria-live="off"
      >
        {visible.length === 0 && <p className="text-subtle">Waiting for events…</p>}
        {visible.map((l) => (
          <div key={l.id} className="flex gap-3 whitespace-pre-wrap break-all hover:bg-white/[0.02]">
            <span className="shrink-0 text-subtle tabular-nums">{new Date(l.at).toLocaleTimeString([], { hour12: false })}</span>
            <span className={cx("w-11 shrink-0 uppercase", LEVEL_STYLE[l.level])}>{l.level}</span>
            <span className="w-20 shrink-0 text-slate-500">{l.kind}</span>
            <span className={l.level === "crit" ? "text-zinc-100" : l.level === "debug" ? "text-subtle" : "text-zinc-400"}>{l.text}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
