import type { Metadata } from "next";
import { Suspense } from "react";

import { SignedInAs } from "@/features/auth/components/SignedInAs";
import { ProjectList } from "@/features/projects/components/ProjectList";

export const metadata: Metadata = { title: "Projects · Stall Watch" };

export default function ProjectsPage() {
  return (
    <main>
      <h1>Projects</h1>
      <Suspense fallback={<p>Loading…</p>}>
        <SignedInAs />
      </Suspense>
      <Suspense fallback={<p>Loading projects…</p>}>
        <ProjectList />
      </Suspense>
    </main>
  );
}
