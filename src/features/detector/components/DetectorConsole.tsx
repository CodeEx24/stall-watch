import { Activity, BellRing, CloudOff, FolderSearch, History, Radar, ShieldX, Timer } from "lucide-react";

import { CellLabel, DATA_ROW_CLASS, DataTable } from "@/components/DataTable";
import { EmptyState } from "@/components/EmptyState";
import { FadeIn, Stagger, StaggerItem } from "@/components/motion/Reveal";
import { StatTile } from "@/components/StatTile";
import { Badge } from "@/components/ui/badge";
import { formatClockTime, formatMonthDay, formatTimeWithSeconds, secondsBetween } from "@/lib/format";
import { cn } from "@/lib/utils";

import { getDetectorConsole, RUN_HISTORY_LIMIT } from "../queries";
import type { StallRunRow } from "../schemas";
import { RunNowButton } from "./RunNowButton";

const RUN_STATUS_VARIANTS = {
  running: "brass",
  succeeded: "healthy",
  failed: "stalled",
} as const satisfies Record<StallRunRow["status"], string>;

const RUN_COLUMNS = [
  { label: "Started" },
  { label: "Finished" },
  { label: "Trigger" },
  { label: "Status" },
  { label: "Projects flagged", isNumeric: true },
  { label: "Alerts created", isNumeric: true },
  { label: "Error" },
];

/** Reads the session, staff status and run history, so render it inside <Suspense>. */
export async function DetectorConsole() {
  const result = await getDetectorConsole();

  if (result.kind === "not-allowed") {
    return (
      <EmptyState
        icon={ShieldX}
        title="Staff only"
        description="This page is only available to Reverie3D staff."
        data-testid="detector-not-allowed"
      />
    );
  }

  if (result.kind === "error") {
    return (
      <EmptyState
        icon={CloudOff}
        tone="error"
        title="History could not load"
        description={result.error}
        data-testid="detector-error"
      />
    );
  }

  const latest = result.runs[0];
  const failedCount = result.runs.filter((run) => run.status === "failed").length;

  return (
    <div className="flex flex-col gap-8">
      <FadeIn className="relative overflow-hidden rounded-2xl bg-graphite p-6 text-ivory shadow-lift sm:p-8">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-24 -right-24 size-72 rounded-full border border-brass/25"
        />
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -top-12 -right-12 size-48 rounded-full border border-brass/35"
        />
        <div className="relative flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex max-w-lg gap-4">
            <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-ivory/10 ring-1 ring-ivory/15">
              <Radar aria-hidden="true" className="size-5 text-brass" />
            </span>
            <div>
              <h2 className="text-2xl font-semibold text-ivory">Run the detector now</h2>
              <p className="mt-1 text-sm leading-relaxed text-ivory/70">
                The detector runs on its own every day. Run it by hand to check every project right away; it
                only alerts each stall once.
              </p>
            </div>
          </div>
          <RunNowButton />
        </div>
      </FadeIn>

      {latest ? (
        <Stagger className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <StatTile
            label="Last run"
            value={
              <span className="text-[1.75rem] whitespace-nowrap sm:text-3xl">{formatClockTime(latest.started_at)}</span>
            }
            hint={`${formatMonthDay(latest.started_at)} · ${latest.trigger === "manual" ? "started by hand" : "scheduled"} · UTC`}
            icon={Timer}
          />
          <StatTile
            label="Last result"
            value={<span className="text-3xl capitalize">{latest.status}</span>}
            hint={failedCount > 0 ? `${failedCount} failed in history` : "No failures in history"}
            icon={Activity}
            isAlarm={latest.status === "failed"}
          />
          <StatTile label="Projects flagged" value={latest.projects_flagged} hint="In the last run" icon={FolderSearch} />
          <StatTile label="Alerts created" value={latest.alerts_created} hint="In the last run" icon={BellRing} />
        </Stagger>
      ) : null}

      <section aria-labelledby="run-history-heading" className="flex flex-col gap-4">
        <div className="flex flex-wrap items-end justify-between gap-2">
          <h2 id="run-history-heading" className="text-3xl font-semibold">
            Run history
          </h2>
          {result.runs.length > 0 ? (
            <p className="text-sm text-muted-foreground">
              Up to the latest {RUN_HISTORY_LIMIT} runs, newest first. Times in UTC.
            </p>
          ) : null}
        </div>
        {result.runs.length === 0 ? (
          <EmptyState
            icon={History}
            title="No runs yet"
            description="The detector has not run yet."
            data-testid="runs-empty"
          />
        ) : (
          <DataTable caption="Detector runs, newest first" columns={RUN_COLUMNS} data-testid="runs-table">
            {result.runs.map((run) => (
              <RunRow key={run.id} run={run} />
            ))}
          </DataTable>
        )}
      </section>
    </div>
  );
}

function RunRow({ run }: { run: StallRunRow }) {
  const duration = secondsBetween(run.started_at, run.finished_at);

  return (
    <StaggerItem
      as="tr"
      data-testid="run"
      data-run-id={run.id}
      data-trigger={run.trigger}
      data-status={run.status}
      data-started-at={run.started_at}
      className={cn(
        DATA_ROW_CLASS,
        run.status === "failed" && "bg-stalled-soft/40",
      )}
    >
      <td className="tabular px-5 py-3.5 font-medium whitespace-nowrap max-md:p-0">
        <CellLabel>Started</CellLabel>
        <time dateTime={run.started_at}>{formatTimeWithSeconds(run.started_at)}</time>
      </td>
      <td className="tabular px-4 py-3.5 whitespace-nowrap text-muted-foreground max-md:p-0">
        <CellLabel>Finished</CellLabel>
        {run.finished_at ? (
          <>
            <time dateTime={run.finished_at}>{formatTimeWithSeconds(run.finished_at)}</time>
            {duration !== null ? <span className="ml-1.5 text-xs">({duration}s)</span> : null}
          </>
        ) : (
          "—"
        )}
      </td>
      <td className="px-4 py-3.5 max-md:p-0">
        <CellLabel>Trigger</CellLabel>
        <Badge variant="outline" className="capitalize">
          {run.trigger}
        </Badge>
      </td>
      <td className="px-4 py-3.5 max-md:p-0">
        <CellLabel>Status</CellLabel>
        <Badge variant={RUN_STATUS_VARIANTS[run.status]} className="capitalize">
          {run.status}
        </Badge>
      </td>
      <td className="tabular px-4 py-3.5 text-right font-medium max-md:p-0 max-md:text-left">
        <CellLabel>Projects flagged</CellLabel>
        {run.projects_flagged}
      </td>
      <td className="tabular px-4 py-3.5 text-right font-medium max-md:p-0 max-md:text-left">
        <CellLabel>Alerts created</CellLabel>
        {run.alerts_created}
      </td>
      <td className="px-5 py-3.5 text-stalled max-md:col-span-2 max-md:p-0 max-md:empty:hidden" data-testid="run-error">
        {run.error_message ?? ""}
      </td>
    </StaggerItem>
  );
}
