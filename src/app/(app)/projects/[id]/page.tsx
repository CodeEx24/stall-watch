import type { Metadata } from "next";
import { Suspense } from "react";

import { PageSkeleton } from "@/components/PageSkeleton";
import { ProjectDetail } from "@/features/selections/components/ProjectDetail";

export const metadata: Metadata = { title: "Project · Stall Watch" };

// Params are runtime data under Cache Components, so they are read inside
// <Suspense>; the static shell holds nothing project-specific.
export default function ProjectPage({ params }: PageProps<"/projects/[id]">) {
  return (
    <Suspense fallback={<PageSkeleton label="Loading project" />}>
      {params.then(({ id }) => (
        <ProjectDetail projectId={id} />
      ))}
    </Suspense>
  );
}
