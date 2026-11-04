"use client";

import { useEffect, useRef, useState, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode } from "react";
import { ChevronLeft, ChevronRight, XIcon } from "./icons";

export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

type Variant = "primary" | "secondary" | "ghost" | "danger";
const VARIANTS: Record<Variant, string> = {
  primary: "bg-fg text-bg hover:bg-zinc-200",
  secondary: "border border-line-strong bg-transparent text-fg hover:bg-elevated",
  ghost: "text-muted hover:bg-elevated hover:text-fg",
  danger: "border border-red-900/70 bg-red-950/40 text-red-200 hover:bg-red-950/70",
};

export function Button({ variant = "secondary", size = "md", className, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: "sm" | "md" }) {
  return (
    <button
      className={cx(
        "inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors disabled:pointer-events-none disabled:opacity-40",
        size === "sm" ? "h-7 px-2.5 text-xs" : "h-9 px-3.5 text-sm",
        VARIANTS[variant],
        className,
      )}
      {...rest}
    />
  );
}

export function Input({ className, ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cx(
        "h-9 w-full rounded-md border border-line-strong bg-transparent px-3 text-sm text-fg placeholder:text-subtle focus:border-zinc-500 focus:outline-none",
        className,
      )}
      {...rest}
    />
  );
}

type Tone = "neutral" | "red" | "amber" | "green" | "slate" | "blue";
const TONES: Record<Tone, string> = {
  neutral: "border-line-strong text-muted",
  red: "border-red-900/70 bg-red-950/40 text-red-300",
  amber: "border-amber-900/70 bg-amber-950/30 text-amber-300",
  green: "border-emerald-900/70 bg-emerald-950/30 text-emerald-300",
  slate: "border-slate-700 bg-slate-900/50 text-slate-300",
  blue: "border-sky-900/70 bg-sky-950/30 text-sky-300",
};

export function Badge({ tone = "neutral", children, className }: { tone?: Tone; children: ReactNode; className?: string }) {
  return <span className={cx("inline-flex h-5 items-center rounded border px-1.5 font-mono text-[11px] leading-none", TONES[tone], className)}>{children}</span>;
}

export function PageHeader({ title, description, children }: { title: string; description?: string; children?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4 border-b border-line px-6 py-5">
      <div>
        <h1 className="text-lg font-semibold tracking-tight">{title}</h1>
        {description && <p className="mt-1 text-sm text-muted">{description}</p>}
      </div>
      {children}
    </div>
  );
}

export function Pagination({ page, pages, total, onPage }: { page: number; pages: number; total: number; onPage: (p: number) => void }) {
  return (
    <div className="flex items-center justify-between border-t border-line px-4 py-3 text-xs text-subtle">
      <span>
        {total.toLocaleString()} result{total === 1 ? "" : "s"}
      </span>
      <div className="flex items-center gap-2">
        <span className="tabular-nums">
          Page {page} of {pages}
        </span>
        <Button size="sm" variant="ghost" aria-label="Previous page" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          <ChevronLeft />
        </Button>
        <Button size="sm" variant="ghost" aria-label="Next page" disabled={page >= pages} onClick={() => onPage(page + 1)}>
          <ChevronRight />
        </Button>
      </div>
    </div>
  );
}

/** Native <dialog> modal: focus trap, Escape and backdrop come for free. */
export function Dialog({ open, onClose, title, children, wide }: { open: boolean; onClose: () => void; title: string; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
      className={cx(
        "m-auto w-[calc(100%-2rem)] rounded-lg border border-line-strong bg-panel p-0 text-fg backdrop:bg-black/70",
        wide ? "max-w-4xl" : "max-w-md",
      )}
    >
      {open && (
        <div>
          <div className="flex items-center justify-between border-b border-line px-5 py-3.5">
            <h2 className="text-sm font-semibold">{title}</h2>
            <button onClick={onClose} aria-label="Close" className="rounded p-1 text-subtle hover:bg-elevated hover:text-fg">
              <XIcon />
            </button>
          </div>
          {children}
        </div>
      )}
    </dialog>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <div className="px-6 py-16 text-center text-sm text-subtle">{children}</div>;
}

export function timeAgo(iso: string | null | undefined) {
  if (!iso) return "never";
  const s = Math.round((Date.now() - Date.parse(iso)) / 1000);
  if (s < 0) {
    const f = -s;
    if (f < 3600) return `in ${Math.ceil(f / 60)}m`;
    if (f < 86400) return `in ${Math.ceil(f / 3600)}h`;
    return `in ${Math.ceil(f / 86400)}d`;
  }
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

export function useDebounced<T>(value: T, ms = 250) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms, setV]);
  return v;
}

