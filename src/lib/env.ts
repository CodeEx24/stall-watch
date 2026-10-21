/**
 * Typed access to the only two environment variables this app uses.
 *
 * Both are public by design: the URL and the publishable key ship to the
 * browser, and Postgres row level security enforces every access rule.
 * The service-role key is never read anywhere in this codebase.
 *
 * `process.env.NEXT_PUBLIC_*` must be referenced literally so Next.js can
 * inline the values at build time.
 */
export type SupabaseEnv = {
  url: string;
  publishableKey: string;
};

let cachedEnv: SupabaseEnv | undefined;

export function getSupabaseEnv(): SupabaseEnv {
  if (cachedEnv) return cachedEnv;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  const missing = [
    !url && "NEXT_PUBLIC_SUPABASE_URL",
    !publishableKey && "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  ].filter(Boolean);

  if (!url || !publishableKey) {
    throw new Error(
      `Missing environment variable(s): ${missing.join(", ")}. ` +
        "Copy .env.example to .env.local and fill in the Supabase URL and publishable key.",
    );
  }

  cachedEnv = { url, publishableKey };
  return cachedEnv;
}
