import { ArrowRight } from "lucide-react";
import Link from "next/link";
import { Suspense } from "react";

import { Button } from "@/components/ui/button";
import { getCurrentUser } from "@/features/auth/queries";

/*
 * Session-aware calls to action for the public landing page.
 *
 * The landing page itself stays static: only these buttons read the session,
 * and each one sits inside its own <Suspense>. The fallback shows only the
 * button that is right for everyone ("Open Stall Watch" → /projects, which
 * sends a signed-out visitor to /login), so a signed-in user never sees
 * "Sign in" flash while the session is checked. This is display only; the
 * proxy, the pages and RLS still decide who can see what.
 */

function ArrowIcon() {
  return (
    <ArrowRight
      aria-hidden="true"
      className="transition-transform duration-(--duration-fast) group-hover:translate-x-0.5"
    />
  );
}

/* ---------- Top navigation bar ---------- */

function NavOpenAppButton() {
  return (
    <Button asChild>
      <Link href="/projects" className="group">
        <span className="sm:hidden">Open app</span>
        <span className="hidden sm:inline">Open Stall Watch</span>
        <ArrowIcon />
      </Link>
    </Button>
  );
}

async function NavActionsForSession() {
  const user = await getCurrentUser();

  if (user) {
    return (
      <Button asChild>
        <Link href="/projects" className="group">
          Projects
          <ArrowIcon />
        </Link>
      </Button>
    );
  }

  return (
    <>
      <Button asChild variant="ghost" className="hidden sm:inline-flex">
        <Link href="/login">Sign in</Link>
      </Button>
      <NavOpenAppButton />
    </>
  );
}

/** Right-hand buttons of the landing nav: "Projects" when signed in, otherwise "Sign in" + "Open Stall Watch". */
export function LandingNavActions() {
  return (
    <Suspense fallback={<NavOpenAppButton />}>
      <NavActionsForSession />
    </Suspense>
  );
}

/* ---------- Closing call to action (dark band near the footer) ---------- */

function ClosingOpenAppButton({ label }: { label: string }) {
  return (
    <Button asChild size="lg" variant="brass">
      <Link href="/projects" className="group">
        {label}
        <ArrowIcon />
      </Link>
    </Button>
  );
}

async function ClosingActionsForSession() {
  const user = await getCurrentUser();

  if (user) {
    return <ClosingOpenAppButton label="Go to your projects" />;
  }

  return (
    <>
      <ClosingOpenAppButton label="Open Stall Watch" />
      <Button
        asChild
        size="lg"
        variant="ghost"
        className="text-ivory/80 hover:bg-ivory/10 hover:text-ivory"
      >
        <Link href="/login">Sign in</Link>
      </Button>
    </>
  );
}

/** Buttons of the closing call to action: no "Sign in" when the visitor is already signed in. */
export function ClosingCtaActions() {
  return (
    <Suspense fallback={<ClosingOpenAppButton label="Open Stall Watch" />}>
      <ClosingActionsForSession />
    </Suspense>
  );
}
