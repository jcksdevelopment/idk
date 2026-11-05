import { PageHeader } from "@/components/ui";
import { BackdoorTable } from "@/components/backdoor-table";

export const metadata = { title: "Backdoors · JCKS Anticheat" };

export default function BackdoorsPage() {
  return (
    <>
      <PageHeader title="Backdoor scanner" description="Results of the last scan of every resource on the game server. Nothing is changed until you confirm an action." />
      <BackdoorTable />
    </>
  );
}
