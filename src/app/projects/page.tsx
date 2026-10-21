import type { Metadata } from "next";
import { Suspense } from "react";

import { SignedInAs } from "@/features/auth/components/SignedInAs";

export const metadata: Metadata = { title: "Projects · Stall Watch" };

// Placeholder: STW-28 builds the real project list.
export default function ProjectsPage() {
  return (
    <main>
      <h1>Projects</h1>
      <Suspense fallback={<p>Loading…</p>}>
        <SignedInAs />
      </Suspense>
      <p>Your projects will be listed here.</p>
    </main>
  );
}
