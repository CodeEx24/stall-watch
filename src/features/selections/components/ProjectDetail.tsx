import { Layers } from "lucide-react";
import { notFound } from "next/navigation";

import { EmptyState } from "@/components/EmptyState";
import { PageHeader } from "@/components/PageHeader";
import { FadeIn, Stagger, StaggerItem } from "@/components/motion/Reveal";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { requireUser } from "@/features/auth/queries";
import { ProjectStatusBadge } from "@/features/projects/components/ProjectStatusBadge";
import { StalledBadge } from "@/features/projects/components/StalledBadge";
import { cn } from "@/lib/utils";

import { getProjectDetail } from "../queries";
import type { RoomView } from "../types";
import { SlotRow } from "./SlotRow";

type ProjectDetailProps = {
  projectId: string;
};

/**
 * The project's slots grouped by room. Reads the session, so render it
 * inside a <Suspense> boundary. A malformed id or a project RLS hides
 * (another org's) renders the not-found page and nothing else: no name,
 * no slot count.
 */
export async function ProjectDetail({ projectId }: ProjectDetailProps) {
  await requireUser();
  const project = await getProjectDetail(projectId);
  if (!project) notFound();

  const slots = project.rooms.flatMap((room) => room.slots);
  const selectedCount = slots.filter((slot) => slot.selection !== null).length;

  return (
    <article data-testid="project-detail">
      <PageHeader
        back={{ href: "/projects", label: "All projects" }}
        eyebrow={project.orgName}
        title={project.name}
        description="Choose a product for every finish slot. Each change is saved for this project and recorded in its history."
        actions={
          <>
            <ProjectStatusBadge status={project.status} />
            {project.isStalled ? <StalledBadge /> : null}
            {project.archivedAt ? <Badge variant="outline">Archived</Badge> : null}
          </>
        }
      />

      {slots.length > 0 ? (
        <SelectionProgress
          selectedCount={selectedCount}
          totalCount={slots.length}
          roomCount={project.rooms.length}
          isStalled={project.isStalled}
        />
      ) : null}

      {project.rooms.length === 0 ? (
        <EmptyState icon={Layers} title="No finish slots yet" description="This project has no slots." />
      ) : (
        <Stagger className="grid grid-cols-1 items-start gap-5 lg:grid-cols-2 [&>*]:min-w-0">
          {project.rooms.map((room) => (
            <StaggerItem key={room.room}>
              <RoomCard room={room} />
            </StaggerItem>
          ))}
        </Stagger>
      )}
    </article>
  );
}

type SelectionProgressProps = {
  selectedCount: number;
  totalCount: number;
  roomCount: number;
  isStalled: boolean;
};

/** The headline figure: how much of the home is specified. */
function SelectionProgress({ selectedCount, totalCount, roomCount, isStalled }: SelectionProgressProps) {
  const ratio = totalCount === 0 ? 0 : selectedCount / totalCount;
  const percent = Math.round(ratio * 100);

  return (
    <FadeIn
      delay={0.08}
      className="relative mb-8 overflow-hidden rounded-2xl bg-graphite p-6 text-ivory shadow-lift sm:p-8"
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 opacity-[0.07] [background-image:linear-gradient(to_right,var(--ivory)_1px,transparent_1px),linear-gradient(to_bottom,var(--ivory)_1px,transparent_1px)] [background-size:32px_32px]"
      />
      <div className="relative flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-semibold tracking-[0.18em] text-brass uppercase">Selections</p>
          <p className="mt-2 font-heading text-6xl leading-none font-semibold tabular">
            {percent}
            <span className="text-3xl text-ivory/60">%</span>
          </p>
          <p className="mt-3 text-sm text-ivory/70" data-testid="selection-progress">
            {selectedCount} of {totalCount} finish slots chosen across {roomCount}{" "}
            {roomCount === 1 ? "room" : "rooms"}
          </p>
        </div>
        {isStalled ? (
          <p className="max-w-xs text-sm leading-relaxed text-ivory/80 sm:text-right">
            <span className="font-medium text-stalled-glow">This project has gone quiet.</span> No builder
            activity recently — a selection today gets it moving again.
          </p>
        ) : null}
      </div>
      <div
        className="relative mt-6 h-1.5 overflow-hidden rounded-full bg-ivory/10"
        role="progressbar"
        aria-label="Finish slots chosen"
        aria-valuemin={0}
        aria-valuemax={totalCount}
        aria-valuenow={selectedCount}
      >
        <div
          className={cn(
            "h-full origin-left rounded-full transition-transform duration-(--duration-slow) ease-(--ease-out-quint)",
            isStalled ? "bg-stalled-glow" : "bg-brass",
          )}
          style={{ transform: `scaleX(${ratio})` }}
        />
      </div>
    </FadeIn>
  );
}

function RoomCard({ room }: { room: RoomView }) {
  const selectedCount = room.slots.filter((slot) => slot.selection !== null).length;
  const isComplete = selectedCount === room.slots.length;
  const headingId = `room-${room.room.replace(/\W+/g, "-").toLowerCase()}`;

  return (
    <Card role="region" data-testid="room" aria-labelledby={headingId} className="gap-0 py-0">
      <header className="flex items-center justify-between gap-3 border-b border-border bg-muted/40 px-5 py-4">
        <h2 id={headingId} className="text-2xl font-semibold">
          {room.room}
        </h2>
        <Badge variant={isComplete ? "healthy" : "outline"} className="tabular">
          {selectedCount}/{room.slots.length} selected
        </Badge>
      </header>
      <ul className="divide-y divide-border">
        {room.slots.map((slot) => (
          <SlotRow key={`${slot.id}:${slot.selection?.lockVersion ?? "empty"}`} slot={slot} />
        ))}
      </ul>
    </Card>
  );
}
