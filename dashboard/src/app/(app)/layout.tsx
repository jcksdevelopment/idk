import { requireSession } from "@/lib/auth";
import { store } from "@/lib/store";
import { Sidebar } from "@/components/sidebar";

export const dynamic = "force-dynamic";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await requireSession();
  return (
    <div className="flex min-h-dvh flex-col md:flex-row">
      <Sidebar session={session} demo={store.demo} />
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
