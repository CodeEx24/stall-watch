import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  async redirects() {
    // The app has no landing page; the proxy sends signed-out visitors on to /login.
    return [{ source: "/", destination: "/projects", permanent: false }];
  },
};

export default nextConfig;
