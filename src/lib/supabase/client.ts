import "client-only";

import { createBrowserClient } from "@supabase/ssr";

import { getSupabaseEnv } from "@/lib/env";

/**
 * Supabase client for Client Components. Same publishable key as the server
 * client, so RLS governs every query exactly as on the server; it never holds
 * any elevated key. Prefer Server Components / Server Actions for data access
 * (CLAUDE.md §3); use this only for browser-side features such as live updates.
 *
 * `createBrowserClient` keeps one shared instance per tab, so calling this
 * repeatedly is cheap.
 */
export function createClient() {
  const { url, publishableKey } = getSupabaseEnv();
  return createBrowserClient(url, publishableKey);
}
