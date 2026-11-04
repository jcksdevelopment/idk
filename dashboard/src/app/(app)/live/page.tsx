import { store } from "@/lib/store";
import { LiveTerminal } from "@/components/live-terminal";

export const metadata = { title: "Live · Sentinel" };

export default function LivePage() {
  return <LiveTerminal initialStats={store.stats()} />;
}
