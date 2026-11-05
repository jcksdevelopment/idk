"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/client";
import type { ServerSettings, SettingsField } from "@/lib/types";
import { Button, cx, Empty, Input, timeAgo } from "./ui";

type Config = Record<string, unknown>;
type Response = { settings: ServerSettings | null; connected: boolean; demo: boolean; canEdit: boolean };

const getPath = (obj: Config, path: string): unknown =>
  path.split(".").reduce<unknown>((o, k) => (o && typeof o === "object" ? (o as Config)[k] : undefined), obj);

function setPath(obj: Config, path: string, value: unknown): Config {
  const copy: Config = structuredClone(obj);
  const keys = path.split(".");
  let o = copy;
  for (const k of keys.slice(0, -1)) o = (o[k] ??= {}) as Config;
  o[keys[keys.length - 1]] = value;
  return copy;
}

export function SettingsEditor() {
  const [data, setData] = useState<Response | null>(null);
  const [draft, setDraft] = useState<Config | null>(null);
  const [active, setActive] = useState<string | null>(null);
  const [status, setStatus] = useState<{ kind: "ok" | "err" | "info"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async (resetDraft: boolean) => {
    const r = await api<Response>("/api/settings?serverId=main");
    setData(r);
    if (resetDraft && r.settings) setDraft(r.settings.config);
    return r;
  }, []);

  useEffect(() => {
    load(true).catch((e) => setStatus({ kind: "err", text: (e as Error).message }));
  }, [load]);

  const original = data?.settings?.config;
  const dirty = useMemo(() => !!draft && !!original && JSON.stringify(draft) !== JSON.stringify(original), [draft, original]);

  // While a change is pending on the game server, poll until it confirms (pushes settings back).
  useEffect(() => {
    if (!data?.settings?.pending) return;
    const t = setInterval(async () => {
      const r = await load(false);
      if (r.settings && !r.settings.pending) {
        setDraft(r.settings.config);
        setStatus({ kind: "ok", text: "Game server applied and saved the settings." });
      }
    }, 2000);
    return () => clearInterval(t);
  }, [data?.settings?.pending, load]);

  async function save() {
    if (!draft) return;
    setBusy(true);
    setStatus(null);
    try {
      const r = await api<{ delivered: string }>("/api/settings", { method: "POST", body: JSON.stringify({ serverId: "main", config: draft }) });
      setStatus(
        r.delivered === "simulated"
          ? { kind: "ok", text: "Saved (demo mode: no game server connected)." }
          : r.delivered === "queued-offline"
            ? { kind: "info", text: "Queued. The game server applies it when it next connects." }
            : { kind: "info", text: "Sent to the game server. Waiting for it to validate and apply…" },
      );
      await load(r.delivered === "simulated");
    } catch (e) {
      setStatus({ kind: "err", text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  async function reloadFromFile() {
    try {
      await api("/api/settings/reload", { method: "POST", body: JSON.stringify({ serverId: "main" }) });
      setStatus({ kind: "info", text: "Asked the game server to re-read config.json." });
    } catch (e) {
      setStatus({ kind: "err", text: (e as Error).message });
    }
  }

  if (!data) return <Empty>Loading…</Empty>;
  const schema = data.settings?.schema;
  if (!data.settings || !schema || !draft) {
    return <Empty>No settings yet. They appear once the game server connects with the dashboard enabled.</Empty>;
  }
  const section = schema.sections.find((s) => s.id === active) ?? schema.sections[0];
  const readOnly = !data.canEdit;

  return (
    <div className="grid md:grid-cols-[220px_1fr]">
      <nav className="flex gap-1 overflow-x-auto border-line px-4 py-4 md:flex-col md:border-r" aria-label="Settings sections">
        {schema.sections.map((s) => (
          <button
            key={s.id}
            onClick={() => setActive(s.id)}
            aria-current={s.id === section.id ? "page" : undefined}
            className={cx("h-8 shrink-0 rounded-md px-2.5 text-left text-sm", s.id === section.id ? "bg-elevated text-fg" : "text-muted hover:bg-elevated/60 hover:text-fg")}
          >
            {s.title}
          </button>
        ))}
      </nav>

      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-3 border-b border-line px-6 py-3 text-xs text-muted">
          <span className="flex items-center gap-2">
            <span className={cx("size-1.5 rounded-full", data.connected ? "bg-emerald-400" : "bg-zinc-600")} />
            {data.connected ? "Game server connected" : data.demo ? "Demo mode" : "Game server offline"}
          </span>
          <span>Last update {timeAgo(data.settings.updatedAt)}</span>
          {data.settings.pending && <span className="text-amber-300">Change pending on game server…</span>}
          {readOnly && <span className="text-amber-300">Read-only: only Head Admins can change settings.</span>}
        </div>

        <div className="divide-y divide-line px-6">
          <h2 className="py-4 text-sm font-semibold">{section.title}</h2>
          {section.fields.map((f) => (
            <div key={f.key} className="grid gap-3 py-3.5 sm:grid-cols-[1fr_280px]">
              <div>
                <label htmlFor={f.key} className="text-sm font-medium">{f.label}</label>
                {f.help && <p className="mt-0.5 text-xs text-subtle">{f.help}</p>}
                <code className="mt-1 block font-mono text-[11px] text-slate-500">{f.key}</code>
              </div>
              <FieldInput field={f} value={getPath(draft, f.key)} disabled={readOnly} onChange={(v) => setDraft(setPath(draft, f.key, v))} />
            </div>
          ))}
        </div>

        <div className="sticky bottom-0 flex flex-wrap items-center gap-2 border-t border-line bg-bg/95 px-6 py-3">
          <p className={cx("flex-1 text-xs", status?.kind === "err" ? "text-red-400" : status?.kind === "ok" ? "text-emerald-300" : "text-muted")} role="status">
            {status?.text ?? (dirty ? "Unsaved changes" : "")}
          </p>
          {!readOnly && (
            <>
              <Button size="sm" variant="ghost" onClick={() => original && setDraft(original)} disabled={!dirty}>Discard</Button>
              <Button size="sm" variant="secondary" onClick={reloadFromFile} disabled={!data.connected}>Reload from file</Button>
              <Button size="sm" variant="primary" onClick={save} disabled={!dirty || busy}>{busy ? "Saving…" : "Save & apply"}</Button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function FieldInput({ field, value, disabled, onChange }: { field: SettingsField; value: unknown; disabled: boolean; onChange: (v: unknown) => void }) {
  switch (field.type) {
    case "bool":
      return (
        <label className="flex h-9 items-center gap-2 text-sm text-muted">
          <input id={field.key} type="checkbox" checked={!!value} disabled={disabled} onChange={(e) => onChange(e.target.checked)} className="size-4 accent-slate-300" />
          {value ? "On" : "Off"}
        </label>
      );
    case "number":
      return (
        <Input id={field.key} type="number" min={field.min} max={field.max} step={field.step ?? "any"} disabled={disabled}
          value={typeof value === "number" ? value : ""}
          onChange={(e) => e.target.value !== "" && !Number.isNaN(+e.target.value) && onChange(+e.target.value)} className="font-mono" />
      );
    case "select":
      return (
        <select id={field.key} value={String(value ?? "")} disabled={disabled} onChange={(e) => onChange(e.target.value)}
          className="h-9 rounded-md border border-line-strong bg-bg px-2 font-mono text-sm">
          {(field.options ?? []).map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      );
    case "list":
    case "codes":
    case "numbers":
      return (
        <ListInput id={field.key} kind={field.type} value={Array.isArray(value) ? value : []} disabled={disabled} onChange={onChange} />
      );
    case "maplist":
      return (
        <MapListInput id={field.key} value={value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, string[]>) : {}} disabled={disabled} onChange={onChange} />
      );
    case "map":
      return (
        <MapInput id={field.key} upper={!!field.upperKeys} value={value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, number>) : {}} disabled={disabled} onChange={onChange} />
      );
    default:
      return <Input id={field.key} value={String(value ?? "")} disabled={disabled} onChange={(e) => onChange(e.target.value)} className="font-mono" />;
  }
}

/** Keeps its own text so typing commas/newlines isn't fought by re-serialisation. */
function ListInput({ id, kind, value, disabled, onChange }: { id: string; kind: "list" | "codes" | "numbers"; value: unknown[]; disabled: boolean; onChange: (v: unknown) => void }) {
  const joined = value.join("\n");
  const [text, setText] = useState(joined);
  useEffect(() => {
    setText((t) => (parse(t, kind).join("\n") === joined ? t : joined));
  }, [joined, kind]);
  return (
    <textarea id={id} value={text} disabled={disabled} spellCheck={false} placeholder="One per line" rows={Math.min(8, Math.max(3, value.length + 1))}
      onChange={(e) => { setText(e.target.value); onChange(parse(e.target.value, kind)); }}
      className="w-full rounded-md border border-line-strong bg-transparent px-3 py-2 font-mono text-xs focus:border-zinc-500 focus:outline-none" />
  );
}

function parse(text: string, kind: "list" | "codes" | "numbers"): unknown[] {
  const items = text.split(/[\n,]/).map((x) => x.trim()).filter(Boolean);
  if (kind === "numbers") return items.map(Number).filter((n) => !Number.isNaN(n));
  if (kind === "codes") return items.map((x) => x.toUpperCase());
  return items;
}

/** CODE=points per line; keeps its own text like ListInput. */
function MapInput({ id, upper, value, disabled, onChange }: { id: string; upper: boolean; value: Record<string, number>; disabled: boolean; onChange: (v: unknown) => void }) {
  const joined = Object.entries(value).map(([k, v]) => `${k}=${v}`).join("\n");
  const [text, setText] = useState(joined);
  useEffect(() => {
    setText((t) => (serialize(parseMap(t, upper)) === joined ? t : joined));
  }, [joined, upper]);
  return (
    <textarea id={id} value={text} disabled={disabled} spellCheck={false} placeholder="key=value, one per line" rows={Math.min(8, Math.max(3, Object.keys(value).length + 1))}
      onChange={(e) => { setText(e.target.value); onChange(parseMap(e.target.value, upper)); }}
      className="w-full rounded-md border border-line-strong bg-transparent px-3 py-2 font-mono text-xs focus:border-zinc-500 focus:outline-none" />
  );
}

function parseMap(text: string, upper: boolean): Record<string, number> {
  const out: Record<string, number> = {};
  for (const line of text.split("\n")) {
    const m = line.trim().match(/^(\S+?)\s*=\s*(-?\d+(?:\.\d+)?)$/);
    if (m) out[upper ? m[1].toUpperCase() : m[1]] = Math.round(+m[2]);
  }
  return out;
}

const serialize = (m: Record<string, number>) => Object.entries(m).map(([k, v]) => `${k}=${v}`).join("\n");

/** resource=a,b per line. */
function MapListInput({ id, value, disabled, onChange }: { id: string; value: Record<string, string[]>; disabled: boolean; onChange: (v: unknown) => void }) {
  const joined = serializeList(value);
  const [text, setText] = useState(joined);
  useEffect(() => {
    setText((t) => (serializeList(parseMapList(t)) === joined ? t : joined));
  }, [joined]);
  return (
    <textarea id={id} value={text} disabled={disabled} spellCheck={false} placeholder="resource=behaviour,behaviour" rows={Math.min(10, Math.max(3, Object.keys(value).length + 1))}
      onChange={(e) => { setText(e.target.value); onChange(parseMapList(e.target.value)); }}
      className="w-full rounded-md border border-line-strong bg-transparent px-3 py-2 font-mono text-xs focus:border-zinc-500 focus:outline-none" />
  );
}

function parseMapList(text: string): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const line of text.split("\n")) {
    const m = line.trim().match(/^(\S+?)\s*=\s*(.+)$/);
    if (m) out[m[1]] = m[2].split(",").map((x) => x.trim().toLowerCase()).filter(Boolean);
  }
  return out;
}

const serializeList = (m: Record<string, string[]>) => Object.entries(m).map(([k, v]) => `${k}=${(v ?? []).join(",")}`).join("\n");
