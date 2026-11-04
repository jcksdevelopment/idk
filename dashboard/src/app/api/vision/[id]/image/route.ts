import { sessionFromRequest } from "@/lib/auth";
import { unauthorized } from "@/lib/http";
import { store } from "@/lib/store";

export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!(await sessionFromRequest())) return unauthorized();
  const { id } = await params;
  const img = store.visionImage(id);
  if (!img) return new Response("not found", { status: 404 });
  return new Response(new Uint8Array(img.data), {
    headers: {
      "Content-Type": img.type,
      "Cache-Control": "private, max-age=3600",
      // Captures are untrusted client data: never let an SVG/JPEG run script in our origin.
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; sandbox",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
