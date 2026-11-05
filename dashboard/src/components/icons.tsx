import type { SVGProps } from "react";

type P = SVGProps<SVGSVGElement>;
const base = { width: 16, height: 16, fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round" } as const;

export const DiscordIcon = (p: P) => (
  <svg viewBox="0 0 24 24" width={16} height={16} fill="currentColor" aria-hidden {...p}>
    <path d="M20.317 4.37a19.79 19.79 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.865-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.74 19.74 0 0 0 3.677 4.37a.07.07 0 0 0-.032.028C.533 9.046-.32 13.58.099 18.058a.082.082 0 0 0 .031.056 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.1 13.1 0 0 1-1.872-.892.077.077 0 0 1-.008-.128c.126-.094.252-.192.372-.291a.074.074 0 0 1 .078-.011c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.099.246.198.373.292a.077.077 0 0 1-.007.128 12.3 12.3 0 0 1-1.873.891.077.077 0 0 0-.041.107c.36.698.772 1.363 1.225 1.993a.076.076 0 0 0 .084.029 19.84 19.84 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03ZM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418Zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418Z" />
  </svg>
);
export const ShieldIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.3 7.5 9.5 4.3-1.2 7.5-4.9 7.5-9.5V6L12 3Z" /></svg>
);
export const TerminalIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="m5 8 4 4-4 4M12 16h7" /></svg>
);
export const UsersIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c.6-3.4 3.3-5.5 6.5-5.5s5.9 2.1 6.5 5.5M16 4.8a3.5 3.5 0 0 1 0 6.4M18.5 14.8c1.6.8 2.7 2.6 3 5.2" /></svg>
);
export const BanIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><circle cx="12" cy="12" r="8.5" /><path d="m6 6 12 12" /></svg>
);
export const EyeIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" /><circle cx="12" cy="12" r="2.8" /></svg>
);
export const SearchIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><circle cx="11" cy="11" r="6.5" /><path d="m20 20-4.2-4.2" /></svg>
);
export const ChevronLeft = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="m15 6-6 6 6 6" /></svg>
);
export const ChevronRight = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="m9 6 6 6-6 6" /></svg>
);
export const LogOutIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M9 20H5.5A1.5 1.5 0 0 1 4 18.5v-13A1.5 1.5 0 0 1 5.5 4H9M15 16l4-4-4-4M19 12H9" /></svg>
);
export const SettingsIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M4 7h10M18 7h2M4 17h4M12 17h8" /><circle cx="16" cy="7" r="2" /><circle cx="10" cy="17" r="2" /></svg>
);
export const BugIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><rect x="7" y="7" width="10" height="13" rx="5" /><path d="M12 7V4M9 4l1.5 3M15 4l-1.5 3M3 12h4M17 12h4M4 18l3-2M20 18l-3-2" /></svg>
);
export const XIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M6 6l12 12M18 6 6 18" /></svg>
);
export const ChartIcon = (p: P) => (
  <svg viewBox="0 0 24 24" {...base} aria-hidden {...p}><path d="M4 20h16M7 16v-5M12 16V6M17 16v-8" /></svg>
);
