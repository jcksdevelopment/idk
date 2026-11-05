import { requireSession } from "@/lib/auth";
import { Overview } from "@/components/overview";

export const metadata = { title: "Overview · JCKS Anticheat" };

export default async function OverviewPage() {
  const session = await requireSession();
  return <Overview name={session.username} />;
}
