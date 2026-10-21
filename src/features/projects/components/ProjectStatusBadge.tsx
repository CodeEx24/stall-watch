import { Badge } from "@/components/ui/badge";

import type { ProjectStatus } from "../schemas";

export const PROJECT_STATUS_LABELS: Record<ProjectStatus, string> = {
  pending_kickoff: "Pending kickoff",
  selection_phase: "Selection phase",
  revision: "Revision",
  complete: "Complete",
};

const STATUS_VARIANTS = {
  pending_kickoff: "outline",
  selection_phase: "brass",
  revision: "secondary",
  complete: "healthy",
} as const satisfies Record<ProjectStatus, string>;

function isProjectStatus(value: string): value is ProjectStatus {
  return value in PROJECT_STATUS_LABELS;
}

/** The project lifecycle status as a tinted pill. Unknown values render as plain text. */
export function ProjectStatusBadge({ status }: { status: string }) {
  if (!isProjectStatus(status)) {
    return <Badge variant="outline">{status}</Badge>;
  }
  return (
    <Badge variant={STATUS_VARIANTS[status]} data-status={status}>
      {PROJECT_STATUS_LABELS[status]}
    </Badge>
  );
}
