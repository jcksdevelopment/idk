import { sessionFromRequest } from "@/lib/auth";
import { unauthorized } from "@/lib/http";
import { store } from "@/lib/store";
import type { LogLine } from "@/lib/types";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  if (!(await sessionFromRequest())) return unauthorized();

  const encoder = new TextEncoder();
  let cleanup = () => {};
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const send = (event: string, data: unknown) => {
        try {
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        } catch {
          cleanup();
        }
      };
      send("backlog", store.recentLog(300));
      const onLog = (line: LogLine) => send("log", line);
      store.bus.on("log", onLog);
      const ping = setInterval(() => send("stats", store.stats()), 5000);
      send("stats", store.stats());
      cleanup = () => {
        store.bus.off("log", onLog);
        clearInterval(ping);
      };
      req.signal.addEventListener("abort", () => {
        cleanup();
        try {
          controller.close();
        } catch {}
      });
    },
    cancel() {
      cleanup();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    },
  });
}
