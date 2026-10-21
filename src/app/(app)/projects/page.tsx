import type { Metadata } from "next";
import { Suspense } from "react";

import { PageHeader } from "@/components/PageHeader";
import { ListSkeleton, StatsSkeleton } from "@/components/PageSkeleton";
import { ProjectList } from "@/features/projects/components/ProjectList";

export const metadata: Metadata = { title: "Projects · Stall Watch" };

export default function ProjectsPage() {
  return (
    <>
      <PageHeader
        eyebrow="Portfolio"
        title="Projects"
        description="Every home in flight, where its finish selections stand, and which ones have gone quiet."
      />
      <Suspense
        fallback={
          <div role="status" className="flex flex-col gap-8">
            <span className="sr-only">Loading projects…</span>
            <StatsSkeleton />
            <ListSkeleton rows={6} />
          </div>
        }
      >
        <ProjectList />
      </Suspense>
    </>
  );
}
