import { CloudOff } from "lucide-react";

import { EmptyState } from "@/components/EmptyState";

import { listProjects } from "../queries";
import { ProjectStats } from "./ProjectStats";
import { ProjectTable } from "./ProjectTable";

/** Reads the session and live data, so render it inside a <Suspense> boundary. */
export async function ProjectList() {
  const result = await listProjects();

  if (!result.ok) {
    return (
      <EmptyState
        icon={CloudOff}
        tone="error"
        title="Projects could not load"
        description={result.message}
      />
    );
  }

  return (
    <>
      {result.projects.length > 0 ? <ProjectStats projects={result.projects} /> : null}
      <ProjectTable projects={result.projects} />
    </>
  );
}
