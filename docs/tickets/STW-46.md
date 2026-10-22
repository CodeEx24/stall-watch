# STW-46 — Landing nav shows "Sign in" to a signed-in user

## Overview
Reported by the owner: after signing in, going back to the landing page (`/`) still showed **Sign in** in the top nav. The landing page from STW-45 was fully static and never read the session, so the nav and the closing call to action always rendered the signed-out buttons.

Now a signed-in visitor sees **Projects** in the nav and **Go to your projects** in the closing call to action, with no "Sign in" anywhere. Signed-out visitors see exactly what they saw before.

## Implementation details
- New `src/features/landing/components/LandingAuthActions.tsx` with two components, `LandingNavActions` and `ClosingCtaActions`. Each reads the session with the existing `getCurrentUser()` (verified `getClaims()`, deduplicated per request) inside its own `<Suspense>`.
- The landing page stays a static shell: the build reports `/` as Partial Prerender (static HTML plus a small streamed part for the buttons), so the page itself still loads from the CDN.
- **No flash of "Sign in":** each Suspense fallback shows only the button that is right for everyone ("Open Stall Watch" → `/projects`, which already redirects signed-out visitors to `/login`). The streamed part then adds "Sign in" for signed-out visitors, or swaps in "Projects" for signed-in ones.
- `LandingNav.tsx` and `ClosingSections.tsx` now render these components instead of hard-coded buttons; unused imports removed.
- Display only. The proxy, the pages and RLS still decide who can see what.

## API changes
None.

## Database changes
None.

## Dependencies on other tickets
STW-27 (auth helpers, proxy), STW-45 (landing page).

## Known limitations
- The closing section's sentence "Sign in with the account your team gave you…" is the same for everyone; only the buttons change.
- The landing page is now Partial Prerender instead of fully static, which costs one session check per visit for the buttons only.

## Testing notes
- `npm run lint`, `npm run typecheck`, `npm run build`: clean. `/` builds as ◐ Partial Prerender.
- Playwright (Edge/Chromium) against `next start` on the local stack, through the real `/login`, with a throwaway local user (random password, deleted afterwards): **13/13 PASS**.
  - Signed out: nav shows Sign in and Open Stall Watch, no Projects; closing CTA shows Sign in; server HTML includes the Sign in button.
  - Signed in: nav shows Projects, no Sign in and no Open Stall Watch; closing CTA shows Go to your projects and no Sign in; Projects opens `/projects`; the full server HTML (static shell plus streamed content) contains no Sign in button, so it can't flash.
- No SQL changed, so `npm run test:db` was not needed.

## Follow-up tasks
- Optional: vary the closing sentence for signed-in visitors.
