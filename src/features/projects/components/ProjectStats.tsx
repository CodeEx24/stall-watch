import { AlertTriangle, Building2, Layers, PencilRuler } from "lucide-react";

import { Stagger } from "@/components/motion/Reveal";
import { StatTile } from "@/components/StatTile";

import type { ProjectRow } from "../schemas";

/**
 * Portfolio summary tiles, derived from the rows the table already shows
 * (no extra query). Archived projects are left out of every figure.
 */
export function ProjectStats({ projects }: { projects: ProjectRow[] }) {
  const active = projects.filter((project) => project.archived_at === null);
  const stalledCount = active.filter((project) => project.is_stalled).length;
  const inSelectionCount = active.filter((project) => project.status === "selection_phase").length;
  const openSlots = active.reduce((sum, project) => sum + project.empty_slots, 0);
  const totalSlots = active.reduce((sum, project) => sum + project.slot_count, 0);

  return (
    <Stagger className="mb-8 grid grid-cols-2 gap-3 lg:grid-cols-4" data-testid="project-stats">
      <StatTile label="Active projects" value={active.length} hint="Archived not counted" icon={Building2} />
      <StatTile label="In selection" value={inSelectionCount} hint="Choosing finishes now" icon={PencilRuler} />
      <StatTile
        label="Stalled"
        value={stalledCount}
        hint={stalledCount === 0 ? "Everything is moving" : "Need a nudge"}
        icon={AlertTriangle}
        isAlarm={stalledCount > 0}
      />
      <StatTile label="Open slots" value={openSlots} hint={`of ${totalSlots} finish slots`} icon={Layers} />
    </Stagger>
  );
}
