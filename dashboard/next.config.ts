import type { NextConfig } from "next";

const config: NextConfig = {
  // Screenshot payloads from the game server arrive as base64 inside ingest batches.
  experimental: { serverActions: { bodySizeLimit: "8mb" } },
  poweredByHeader: false,
};

export default config;
