import Link from "next/link";

import type { ProjectRow, ProjectStatus } from "../schemas";
import styles from "./ProjectTable.module.css";
import { StalledBadge } from "./StalledBadge";

const STATUS_LABELS: Record<ProjectStatus, string> = {
  pending_kickoff: "Pending kickoff",
  selection_phase: "Selection phase",
  revision: "Revision",
  complete: "Complete",
};

type ProjectTableProps = {
  projects: ProjectRow[];
};

export function ProjectTable({ projects }: ProjectTableProps) {
  if (projects.length === 0) {
    return <p>No projects yet.</p>;
  }

  return (
    <table className={styles.table} data-testid="project-table">
      <thead>
        <tr>
          <th scope="col">Project</th>
          <th scope="col">Builder</th>
          <th scope="col">Status</th>
          <th scope="col" className={styles.numeric}>
            Empty slots
          </th>
          <th scope="col">Due date</th>
          <th scope="col">Stalled</th>
        </tr>
      </thead>
      <tbody>
        {projects.map((project) => (
          <ProjectTableRow key={project.id} project={project} />
        ))}
      </tbody>
    </table>
  );
}

function ProjectTableRow({ project }: { project: ProjectRow }) {
  const isArchived = project.archived_at !== null;

  return (
    <tr
      className={isArchived ? styles.archivedRow : undefined}
      data-testid="project-row"
      data-project-id={project.id}
    >
      <th scope="row">
        <Link href={`/projects/${project.id}`}>{project.name}</Link>{" "}
        {isArchived && <span className={styles.archived}>Archived</span>}
      </th>
      <td>{project.org_name}</td>
      <td>{STATUS_LABELS[project.status]}</td>
      <td className={styles.numeric}>
        {project.empty_slots} of {project.slot_count}
      </td>
      <td>
        {project.selection_due_date ? (
          <time dateTime={project.selection_due_date}>
            {project.selection_due_date}
          </time>
        ) : (
          "—"
        )}
      </td>
      <td>{project.is_stalled && <StalledBadge />}</td>
    </tr>
  );
}
