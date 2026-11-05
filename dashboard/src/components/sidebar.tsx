"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BanIcon, EyeIcon, LogOutIcon, ShieldIcon, TerminalIcon, UsersIcon } from "./icons";
import { cx } from "./ui";
import type { Session } from "@/lib/types";

const NAV = [
  { href: "/live", label: "Live", icon: TerminalIcon },
  { href: "/players", label: "Players", icon: UsersIcon },
  { href: "/bans", label: "Bans", icon: BanIcon },
  { href: "/vision", label: "Vision Vault", icon: EyeIcon },
];

export function Sidebar({ session, demo }: { session: Session; demo: boolean }) {
  const path = usePathname();
  return (
    <aside className="flex shrink-0 flex-col border-b border-line md:h-dvh md:w-56 md:border-r md:border-b-0">
      <div className="flex h-14 items-center gap-2.5 px-5">
        <ShieldIcon width={18} height={18} />
        <span className="text-sm font-semibold tracking-tight">JCKS Anticheat</span>
        {demo && <span className="ml-auto rounded border border-line-strong px-1.5 py-0.5 font-mono text-[10px] uppercase text-subtle">demo</span>}
      </div>
      <nav className="flex gap-1 overflow-x-auto px-3 pb-3 md:flex-col md:pb-0" aria-label="Main">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = path === href || path.startsWith(href + "/");
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className={cx(
                "flex h-8 shrink-0 items-center gap-2.5 rounded-md px-2.5 text-sm transition-colors",
                active ? "bg-elevated text-fg" : "text-muted hover:bg-elevated/60 hover:text-fg",
              )}
            >
              <Icon />
              {label}
            </Link>
          );
        })}
      </nav>
      <div className="mt-auto hidden items-center gap-2.5 border-t border-line px-4 py-3 md:flex">
        <span className="grid size-7 place-items-center rounded-full bg-zinc-800 text-xs font-medium">{session.avatar}</span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm">{session.username}</p>
          <p className="truncate text-xs text-subtle">{session.role}</p>
        </div>
        <form action="/api/auth/logout" method="post">
          <button aria-label="Sign out" title="Sign out" className="rounded p-1.5 text-subtle hover:bg-elevated hover:text-fg">
            <LogOutIcon />
          </button>
        </form>
      </div>
    </aside>
  );
}
