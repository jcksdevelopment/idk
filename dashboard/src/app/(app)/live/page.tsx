import { store } from "@/lib/store";
import { LiveTerminal } from "@/components/live-terminal";

export const metadata = { title: "Live · JCKS Anticheat" };

export default function LivePage() {
  return <LiveTerminal initialStats={store.stats()} />;
}
