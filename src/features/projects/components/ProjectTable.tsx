import { ArrowUpRight, FolderOpen } from "lucide-react";
import Link from "next/link";

import { CellLabel, DATA_ROW_CLASS, DataTable } from "@/components/DataTable";
import { EmptyState } from "@/components/EmptyState";
import { StaggerItem } from "@/components/motion/Reveal";
import { Badge } from "@/components/ui/badge";
import { formatDateOnly } from "@/lib/format";
import { cn } from "@/lib/utils";

import type { ProjectRow } from "../schemas";
import { ProjectStatusBadge } from "./ProjectStatusBadge";
import { OnTrackBadge, StalledBadge } from "./StalledBadge";

type ProjectTableProps = {
  projects: ProjectRow[];
};

const COLUMNS = [
  { label: "Project" },
  { label: "Builder" },
  { label: "Status" },
  { label: "Selections" },
  { label: "Due date" },
  { label: "Health" },
];

/** Every project the caller can see (RLS decides which). */
export function ProjectTable({ projects }: ProjectTableProps) {
  if (projects.length === 0) {
    return (
      <EmptyState
        icon={FolderOpen}
        title="No projects yet"
        description="Projects appear here as soon as your builder adds them."
      />
    );
  }

  return (
    <DataTable
      caption="Projects, with status, open finish slots and due date"
      columns={COLUMNS}
      data-testid="project-table"
    >
      {projects.map((project) => (
        <ProjectTableRow key={project.id} project={project} />
      ))}
    </DataTable>
  );
}

function ProjectTableRow({ project }: { project: ProjectRow }) {
  const isArchived = project.archived_at !== null;
  const filledSlots = project.slot_count - project.empty_slots;
  const progress = project.slot_count === 0 ? 0 : filledSlots / project.slot_count;

  return (
    <StaggerItem
      as="tr"
      className={cn(
        DATA_ROW_CLASS,
        "max-md:gap-y-4",
        isArchived && "opacity-60",
        project.is_stalled && "md:shadow-[inset_3px_0_0_var(--stalled)]",
      )}
      data-testid="project-row"
      data-project-id={project.id}
    >
      <th scope="row" className="px-5 py-4 text-left font-normal max-md:col-span-2 max-md:p-0">
        <Link
          href={`/projects/${project.id}`}
          className="inline-flex items-center gap-1.5 font-heading text-xl leading-tight font-semibold text-foreground after:absolute after:inset-0 after:content-[''] hover:text-brass-ink"
        >
          {project.name}
          <ArrowUpRight
            aria-hidden="true"
            className="size-4 text-muted-foreground opacity-0 transition-[opacity,transform] duration-(--duration-fast) group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:opacity-100"
          />
        </Link>
        {isArchived ? (
          <Badge variant="outline" className="ml-2 align-middle">
            Archived
          </Badge>
        ) : null}
      </th>
      <td className="px-4 py-4 text-muted-foreground max-md:p-0">
        <CellLabel>Builder</CellLabel>
        {project.org_name}
      </td>
      <td className="px-4 py-4 max-md:p-0">
        <CellLabel>Status</CellLabel>
        <ProjectStatusBadge status={project.status} />
      </td>
      <td className="px-4 py-4 max-md:col-span-2 max-md:p-0">
        <CellLabel>Selections</CellLabel>
        <div className="flex min-w-36 flex-col gap-1.5">
          <span className="tabular text-xs text-muted-foreground">
            <span className="font-medium text-foreground">
              {project.empty_slots} of {project.slot_count}
            </span>{" "}
            open
          </span>
          <span className="h-1.5 w-full overflow-hidden rounded-full bg-muted" aria-hidden="true">
            <span
              className={cn(
                "block h-full origin-left rounded-full transition-transform duration-(--duration-slow) ease-(--ease-out-quint)",
                project.is_stalled ? "bg-stalled" : "bg-brass",
              )}
              style={{ transform: `scaleX(${progress})` }}
            />
          </span>
        </div>
      </td>
      <td className="tabular px-4 py-4 text-muted-foreground max-md:p-0">
        <CellLabel>Due date</CellLabel>
        {project.selection_due_date ? (
          <time dateTime={project.selection_due_date}>{formatDateOnly(project.selection_due_date)}</time>
        ) : (
          "—"
        )}
      </td>
      <td className="px-5 py-4 max-md:p-0">
        <CellLabel>Health</CellLabel>
        {project.is_stalled ? <StalledBadge /> : isArchived ? null : <OnTrackBadge />}
      </td>
    </StaggerItem>
  );
}
