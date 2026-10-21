import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { connection } from "next/server";

import { getSupabaseEnv } from "@/lib/env";

/**
 * Per-request Supabase client for Server Components, Server Actions and
 * Route Handlers. Uses the publishable key only, so every query runs as the
 * signed-in user and RLS decides what it can see.
 *
 * Always create a new client per request; never share one across requests.
 */
export async function createClient() {
  // Request-time only (Cache Components): connection() keeps auth and data
  // reads out of any prerender, including runtime prefetches, where the
  // token expiry check (Date.now()) is not allowed. Never cache these reads.
  await connection();
  const cookieStore = await cookies();
  const { url, publishableKey } = getSupabaseEnv();

  return createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Components cannot set cookies. That is safe to ignore
          // because the proxy (src/proxy.ts) refreshes the session on every
          // request. Server Actions and Route Handlers can set them.
        }
      },
    },
  });
}
