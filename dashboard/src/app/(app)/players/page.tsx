import { PageHeader } from "@/components/ui";
import { PlayersTable } from "@/components/players-table";

export const metadata = { title: "Players · JCKS Anticheat" };

export default function PlayersPage() {
  return (
    <>
      <PageHeader title="Players" description="Everyone the game server has reported, with live suspicion scores." />
      <PlayersTable />
    </>
  );
}
