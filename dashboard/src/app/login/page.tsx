import { redirect } from "next/navigation";
import { getSession, STAFF_PROFILES } from "@/lib/auth";
import { ShieldIcon } from "@/components/icons";

const ROLE_TEXT: Record<string, string> = {
  "Head Admin": "Everything, including settings, integrations and backdoor actions",
  Moderator: "Kick, ban, unban and captures",
  Support: "Read-only: live feed, players and captures",
};

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  if (await getSession()) redirect("/overview");
  const { error } = await searchParams;

  return (
    <main className="relative grid min-h-dvh place-items-center overflow-hidden px-4">
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(148,163,184,0.10),transparent_60%)]" />
      <div className="relative w-full max-w-[400px]">
        <div className="mb-8 flex items-center gap-2.5">
          <div className="grid size-9 place-items-center rounded-lg border border-line-strong bg-panel">
            <ShieldIcon width={18} height={18} />
          </div>
          <div>
            <p className="text-[15px] font-semibold tracking-tight">JCKS Anticheat</p>
            <p className="text-xs text-subtle">Staff console</p>
          </div>
        </div>

        <form action="/api/auth/demo" method="post" className="rounded-xl border border-line bg-panel/80 p-5 shadow-2xl shadow-black/40 backdrop-blur">
          <h1 className="text-lg font-semibold tracking-tight">Sign in</h1>
          <p className="mt-1 text-sm text-muted">Pick a staff profile. This login is a demo: no password and no external account.</p>

          {error && (
            <p role="alert" className="mt-4 rounded-md border border-red-900/60 bg-red-950/30 px-3 py-2 text-sm text-red-300">Choose a profile to continue.</p>
          )}

          <fieldset className="mt-5 min-w-0 space-y-2">
            <legend className="sr-only">Staff profile</legend>
            {STAFF_PROFILES.map((u, i) => (
              <label key={u.id} className="flex cursor-pointer items-center gap-3 rounded-lg border border-line px-3 py-2.5 transition-colors hover:border-line-strong hover:bg-elevated has-[:checked]:border-slate-400 has-[:checked]:bg-elevated">
                <input type="radio" name="profile" value={u.id} defaultChecked={i === 0} className="sr-only" />
                <span className="grid size-9 shrink-0 place-items-center rounded-full bg-slate-800 text-sm font-semibold text-slate-200">{u.avatar}</span>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2 text-sm font-medium">
                    {u.username}
                    <span className="rounded border border-line-strong px-1.5 py-px text-[10px] font-normal uppercase tracking-wide text-muted">{u.role}</span>
                  </span>
                  <span className="mt-0.5 block truncate text-xs text-subtle">{ROLE_TEXT[u.role]}</span>
                </span>
              </label>
            ))}
          </fieldset>

          <button type="submit" className="mt-5 flex h-10 w-full items-center justify-center rounded-md bg-fg text-sm font-medium text-bg transition-colors hover:bg-zinc-200">
            Continue
          </button>
        </form>

        <p className="mt-5 text-center text-xs text-subtle">Replace with real Discord OAuth2 before exposing the dashboard to the internet.</p>
      </div>
    </main>
  );
}
