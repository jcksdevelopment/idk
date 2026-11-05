import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";
import { DiscordIcon, ShieldIcon } from "@/components/icons";

const ERRORS: Record<string, string> = {
  access_denied: "Authorization was cancelled.",
  invalid_state: "Your sign-in link expired. Try again.",
  invalid_code: "Discord returned an unknown account.",
};

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  if (await getSession()) redirect("/live");
  const { error } = await searchParams;

  return (
    <main className="grid min-h-dvh place-items-center px-6">
      <div className="w-full max-w-[360px]">
        <div className="mb-10 flex items-center gap-2.5 text-fg">
          <ShieldIcon width={20} height={20} />
          <span className="text-[15px] font-semibold tracking-tight">JCKS Anticheat</span>
        </div>

        <h1 className="text-2xl font-semibold tracking-tight">Sign in</h1>
        <p className="mt-2 text-sm text-muted">Staff access to detections, players, bans and the Vision Vault.</p>

        {error && (
          <p role="alert" className="mt-6 rounded-md border border-red-900/60 bg-red-950/30 px-3 py-2 text-sm text-red-300">
            {ERRORS[error] ?? "Sign-in failed."}
          </p>
        )}

        <a
          href="/api/auth/discord"
          className="mt-8 flex h-10 w-full items-center justify-center gap-2 rounded-md bg-fg text-sm font-medium text-bg transition-colors hover:bg-zinc-200"
        >
          <DiscordIcon />
          Continue with Discord
        </a>

        <p className="mt-6 text-xs leading-relaxed text-subtle">
          Mock OAuth2 flow for development. It follows the Discord authorization-code flow but never contacts Discord.
        </p>
      </div>
    </main>
  );
}
