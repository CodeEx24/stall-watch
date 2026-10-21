import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv } from "@/lib/env";

/** Routes a signed-out visitor may open. Everything else needs a session. */
const PUBLIC_PATHS = new Set(["/login"]);

const SIGNED_IN_HOME = "/projects";
const SIGN_IN_PATH = "/login";

/**
 * Refreshes the Supabase session cookie on every request and redirects
 * signed-out visitors to /login (and signed-in visitors away from /login).
 *
 * This is an optimistic, convenience check. Pages and Server Actions still
 * verify the user themselves, and RLS in Postgres is the real wall.
 */
export async function updateSession(request: NextRequest) {
  const { url, publishableKey } = getSupabaseEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
        // Cache-Control headers that stop a CDN caching a refreshed session.
        for (const [key, value] of Object.entries(headers)) {
          response.headers.set(key, value);
        }
      },
    },
  });

  // Do not run code between createServerClient and getClaims(): getClaims()
  // validates the JWT (signature, expiry) and refreshes it when needed.
  // Never trust getSession() on the server; it does not validate the token.
  const { data } = await supabase.auth.getClaims();
  const isSignedIn = Boolean(data?.claims?.sub);

  const { pathname } = request.nextUrl;
  const isPublic = PUBLIC_PATHS.has(pathname);

  if (!isSignedIn && !isPublic) {
    return redirectKeepingCookies(request, response, SIGN_IN_PATH);
  }
  if (isSignedIn && pathname === SIGN_IN_PATH) {
    return redirectKeepingCookies(request, response, SIGNED_IN_HOME);
  }

  return response;
}

/**
 * Redirect to a fixed internal path, carrying over any refreshed session
 * cookies so the browser and server stay in sync.
 */
function redirectKeepingCookies(
  request: NextRequest,
  response: NextResponse,
  path: string,
) {
  const target = request.nextUrl.clone();
  target.pathname = path;
  target.search = "";

  const redirect = NextResponse.redirect(target);
  for (const cookie of response.cookies.getAll()) {
    redirect.cookies.set(cookie);
  }
  const cacheControl = response.headers.get("cache-control");
  if (cacheControl) redirect.headers.set("cache-control", cacheControl);
  return redirect;
}
