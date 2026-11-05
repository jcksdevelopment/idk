import type { NextConfig } from "next";

const config: NextConfig = {
  experimental: { serverActions: { bodySizeLimit: "8mb" } },
  poweredByHeader: false,
};

export default config;
