import { PageHeader } from "@/components/ui";
import { BansTable } from "@/components/bans-table";

export const metadata = { title: "Bans · JCKS Anticheat" };

export default function BansPage() {
  return (
    <>
      <PageHeader title="Bans" description="Every ban the game server has issued, keyed to all of the player's identifiers." />
      <BansTable />
    </>
  );
}
