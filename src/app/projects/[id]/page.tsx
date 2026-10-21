import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";

import { ProjectDetail } from "@/features/selections/components/ProjectDetail";

export const metadata: Metadata = { title: "Project · Stall Watch" };

// Params are runtime data under Cache Components, so they are read inside
// <Suspense>; the static shell holds nothing project-specific.
export default function ProjectPage({ params }: PageProps<"/projects/[id]">) {
  return (
    <main>
      <p>
        <Link href="/projects">← Projects</Link>
      </p>
      <Suspense fallback={<p>Loading…</p>}>
        {params.then(({ id }) => (
          <ProjectDetail projectId={id} />
        ))}
      </Suspense>
    </main>
  );
}
