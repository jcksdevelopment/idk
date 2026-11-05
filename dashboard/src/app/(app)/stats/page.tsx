import { PageHeader } from "@/components/ui";
import { StatsView } from "@/components/stats-view";

export const metadata = { title: "Stats · JCKS Anticheat" };

export default function StatsPage() {
  return (
    <>
      <PageHeader title="Detection stats" description="Which detections fire, how often and for how many different players. Use it to spot false positives before you enforce." />
      <StatsView />
    </>
  );
}
