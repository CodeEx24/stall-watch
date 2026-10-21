import Link from "next/link";

import { BrandMark } from "@/components/brand/BrandMark";
import { Skeleton } from "@/components/ui/skeleton";
import { countMyUnreadAlerts } from "@/features/alerts/queries";
import { requireUser } from "@/features/auth/queries";
import { isSignedInUserStaff } from "@/features/detector/queries";

import { NavLinks } from "./NavLinks";
import { UserMenu } from "./UserMenu";

/** Frosted bar shared by the real header and its loading skeleton. */
function HeaderFrame({ children }: { children: React.ReactNode }) {
  return (
    <header className="sticky top-0 z-40 border-b border-border/70 bg-background/75 backdrop-blur-xl backdrop-saturate-150">
      <div className="mx-auto flex w-full max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-4 py-3 sm:px-6 lg:px-8">
        {children}
      </div>
    </header>
  );
}

/**
 * The signed-in app header: brand, navigation, unread-alert count and the
 * account menu. Reads the session, so render it inside <Suspense>.
 */
export async function AppHeader() {
  const user = await requireUser();
  const [isStaff, unreadAlertCount] = await Promise.all([
    isSignedInUserStaff(),
    countMyUnreadAlerts(),
  ]);

  return (
    <HeaderFrame>
      <Link
        href="/projects"
        className="rounded-xl focus-visible:outline-offset-4"
        aria-label="Stall Watch — projects"
      >
        <BrandMark />
      </Link>
      <div className="order-last w-full md:order-none md:ml-4 md:w-auto">
        <NavLinks isStaff={isStaff} unreadAlertCount={unreadAlertCount} />
      </div>
      <div className="ml-auto">
        <UserMenu email={user.email ?? user.id} isStaff={isStaff} />
      </div>
    </HeaderFrame>
  );
}

export function AppHeaderSkeleton() {
  return (
    <HeaderFrame>
      <BrandMark />
      <Skeleton className="order-last h-11 w-full rounded-xl md:order-none md:ml-4 md:w-72" />
      <Skeleton className="ml-auto h-10 w-10 rounded-xl lg:w-52" />
    </HeaderFrame>
  );
}
