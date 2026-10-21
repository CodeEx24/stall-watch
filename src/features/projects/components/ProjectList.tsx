import { listProjects } from "../queries";
import { ProjectTable } from "./ProjectTable";

/** Reads the session and live data, so render it inside a <Suspense> boundary. */
export async function ProjectList() {
  const result = await listProjects();

  if (!result.ok) {
    return <p role="alert">{result.message}</p>;
  }
  return <ProjectTable projects={result.projects} />;
}
