import { Suspense } from "react";

import { AppHeader, AppHeaderSkeleton } from "@/components/app-shell/AppHeader";

/**
 * Shell for every signed-in page. The header reads the session, so it streams
 * in behind a skeleton; the proxy has already sent signed-out visitors to
 * /login, and each page still verifies the user itself.
 */
export default function AppLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="flex min-h-dvh flex-col">
      <a
        href="#main"
        className="sr-only z-50 rounded-lg bg-graphite px-4 py-2 text-ivory focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
      >
        Skip to content
      </a>
      <Suspense fallback={<AppHeaderSkeleton />}>
        <AppHeader />
      </Suspense>
      <main id="main" className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
        {children}
      </main>
      <footer className="border-t border-border/70">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-1 px-4 py-6 text-xs text-muted-foreground sm:flex-row sm:justify-between sm:px-6 lg:px-8">
          <span>Stall Watch · finish selections, kept moving.</span>
          <span>Times shown in UTC.</span>
        </div>
      </footer>
    </div>
  );
}
