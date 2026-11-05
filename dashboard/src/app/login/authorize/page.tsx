import { MOCK_DISCORD_USERS } from "@/lib/auth";
import { DiscordIcon, ShieldIcon } from "@/components/icons";

/** Stand-in for discord.com/oauth2/authorize. */
export default async function AuthorizePage({ searchParams }: { searchParams: Promise<{ state?: string; scope?: string }> }) {
  const { state = "", scope = "identify" } = await searchParams;
  const scopes = scope.split(" ").filter(Boolean);

  return (
    <main className="grid min-h-dvh place-items-center px-6">
      <form action="/api/auth/callback" method="get" className="w-full max-w-[400px] rounded-lg border border-line bg-panel">
        <input type="hidden" name="state" value={state} />

        <div className="flex items-center gap-3 border-b border-line px-5 py-4">
          <div className="grid size-9 place-items-center rounded-md border border-line-strong text-muted">
            <DiscordIcon />
          </div>
          <div className="text-subtle">⇄</div>
          <div className="grid size-9 place-items-center rounded-md border border-line-strong text-fg">
            <ShieldIcon />
          </div>
          <div className="ml-1">
            <p className="text-sm font-medium">JCKS Anticheat</p>
            <p className="text-xs text-subtle">wants to access your Discord account</p>
          </div>
        </div>

        <fieldset className="px-5 pt-4">
          <legend className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">Sign in as</legend>
          <div className="divide-y divide-line overflow-hidden rounded-md border border-line">
            {MOCK_DISCORD_USERS.map((u, i) => (
              <label key={u.id} className="flex cursor-pointer items-center gap-3 px-3 py-2.5 hover:bg-elevated has-[:checked]:bg-elevated">
                <input type="radio" name="code" value={`mock_${u.id}`} defaultChecked={i === 0} className="accent-slate-400" />
                <span className="grid size-7 place-items-center rounded-full bg-zinc-800 text-xs font-medium">{u.avatar}</span>
                <span className="text-sm">{u.username}</span>
                <span className="ml-auto text-xs text-subtle">{u.role}</span>
              </label>
            ))}
          </div>
        </fieldset>

        <div className="px-5 py-4">
          <p className="mb-2 text-xs font-medium uppercase tracking-wider text-subtle">This will allow JCKS Anticheat to</p>
          <ul className="space-y-1.5 text-sm text-muted">
            {scopes.includes("identify") && <li>• Access your username and avatar</li>}
            {scopes.includes("guilds.members.read") && <li>• Read your roles in the community server</li>}
          </ul>
        </div>

        <div className="flex gap-2 border-t border-line px-5 py-4">
          <a href="/login?error=access_denied" className="flex h-9 flex-1 items-center justify-center rounded-md border border-line-strong text-sm text-muted hover:bg-elevated hover:text-fg">
            Cancel
          </a>
          <button type="submit" className="h-9 flex-1 rounded-md bg-fg text-sm font-medium text-bg hover:bg-zinc-200">
            Authorize
          </button>
        </div>
      </form>
    </main>
  );
}
