"use client";

import { BellRing, Check, FolderClock, LayoutGrid, PencilRuler, Play, Radar } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useId, useRef, useState, type KeyboardEvent } from "react";

import { Badge } from "@/components/ui/badge";
import { ProjectStatusBadge } from "@/features/projects/components/ProjectStatusBadge";
import { OnTrackBadge, StalledBadge } from "@/features/projects/components/StalledBadge";
import { DURATION_SLOW, EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

type TourStep = {
  id: string;
  label: string;
  icon: typeof LayoutGrid;
  title: string;
  points: string[];
  screen: () => React.ReactNode;
};

/** Small framed "screen" used by every tour step. */
function Screen({ path, children }: { path: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-2xl bg-background shadow-[0_30px_60px_-30px_rgb(28_25_23/0.4)] ring-1 ring-border">
      <div className="flex items-center gap-2 border-b border-border bg-muted/60 px-4 py-2.5">
        <span className="size-2 rounded-full bg-stalled/50" />
        <span className="size-2 rounded-full bg-brass/60" />
        <span className="size-2 rounded-full bg-healthy/50" />
        <span className="ml-2 text-[0.6875rem] text-muted-foreground">{path}</span>
      </div>
      <div className="p-5">{children}</div>
    </div>
  );
}

const STEPS: TourStep[] = [
  {
    id: "projects",
    label: "Projects",
    icon: LayoutGrid,
    title: "Your whole portfolio at a glance",
    points: [
      "Every project you can see, with its builder and lifecycle status",
      "Open finish slots and progress for each home",
      "Stalled projects stand out — in terracotta, at the top of mind",
    ],
    screen: () => (
      <Screen path="/projects">
        <p className="font-heading text-2xl font-semibold">Projects</p>
        <ul className="mt-4 flex flex-col gap-2">
          {[
            { name: "Lot 14", status: "selection_phase", isStalled: true, open: "6 of 12" },
            { name: "Unit 5A", status: "selection_phase", isStalled: false, open: "3 of 10" },
            { name: "Lot 9", status: "revision", isStalled: false, open: "1 of 8" },
          ].map((row) => (
            <li
              key={row.name}
              className={cn(
                "flex flex-wrap items-center justify-between gap-2 rounded-xl bg-card px-4 py-3 ring-1 ring-border",
                row.isStalled && "shadow-[inset_3px_0_0_var(--stalled)]",
              )}
            >
              <span className="font-heading text-lg font-semibold">{row.name}</span>
              <ProjectStatusBadge status={row.status} />
              <span className="text-xs text-muted-foreground">{row.open} open</span>
              {row.isStalled ? <StalledBadge /> : <OnTrackBadge />}
            </li>
          ))}
        </ul>
      </Screen>
    ),
  },
  {
    id: "selections",
    label: "Selections",
    icon: PencilRuler,
    title: "Pick finishes in seconds",
    points: [
      "Rooms laid out as cards, slots listed inside",
      "Set, change or clear — the new choice appears instantly",
      "Two people editing the same slot? The second is told, nothing is lost",
    ],
    screen: () => (
      <Screen path="/projects/lot-14">
        <div className="rounded-xl bg-graphite p-4 text-ivory">
          <p className="text-[0.625rem] font-semibold tracking-[0.18em] text-brass uppercase">Selections</p>
          <p className="font-heading text-4xl font-semibold">
            58<span className="text-xl text-ivory/60">%</span>
          </p>
          <div className="mt-3 h-1 overflow-hidden rounded-full bg-ivory/10">
            <div className="h-full w-[58%] rounded-full bg-brass" />
          </div>
        </div>
        <div className="mt-4 rounded-xl bg-card ring-1 ring-border">
          <div className="flex items-center justify-between border-b border-border px-4 py-2.5">
            <span className="font-heading text-lg font-semibold">Primary bath</span>
            <Badge variant="outline">1/2 selected</Badge>
          </div>
          <div className="flex items-center justify-between px-4 py-3">
            <div>
              <p className="text-[0.625rem] font-semibold tracking-[0.14em] text-muted-foreground uppercase">Floor tile</p>
              <p className="text-sm font-medium">Honed travertine, 12×24</p>
            </div>
            <span className="flex items-center gap-1 text-xs text-healthy">
              <Check className="size-3.5" /> Saved
            </span>
          </div>
          <div className="flex flex-col gap-2 border-t border-border px-4 py-3 sm:flex-row">
            <span className="flex h-9 flex-1 items-center rounded-lg border border-brass bg-card px-3 text-sm ring-3 ring-ring/20">
              Brushed nickel widespread faucet
            </span>
            <span className="grid h-9 place-items-center rounded-lg bg-brass px-4 text-sm font-medium text-graphite">Set</span>
          </div>
        </div>
      </Screen>
    ),
  },
  {
    id: "alerts",
    label: "Alerts",
    icon: BellRing,
    title: "Hear about a stall before the deadline does",
    points: [
      "One alert per stall for each of the builder’s admins",
      "Late changes after a project wraps are flagged separately",
      "Mark as read and get back to work — the count in the nav keeps up",
    ],
    screen: () => (
      <Screen path="/alerts">
        <p className="font-heading text-2xl font-semibold">Alerts</p>
        <div className="mt-4 flex flex-col gap-3">
          <div className="relative flex gap-3 overflow-hidden rounded-xl bg-card p-4 ring-1 ring-border">
            <span className="absolute inset-y-0 left-0 w-1 bg-gradient-to-b from-brass to-stalled" />
            <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-stalled-soft text-stalled">
              <FolderClock className="size-4" />
            </span>
            <div>
              <div className="flex gap-1.5">
                <Badge className="h-5 px-2 text-[0.625rem]">New</Badge>
                <Badge variant="stalled" className="h-5 px-2 text-[0.625rem]">
                  Stalled
                </Badge>
              </div>
              <p className="mt-1 font-heading text-lg font-semibold">Lot 14</p>
              <p className="text-xs text-muted-foreground">No builder activity for 7 days during selection.</p>
            </div>
          </div>
          <div className="flex gap-3 rounded-xl bg-card/60 p-4 opacity-70 ring-1 ring-border">
            <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-muted text-muted-foreground">
              <FolderClock className="size-4" />
            </span>
            <div>
              <Badge variant="brass" className="h-5 px-2 text-[0.625rem]">
                Late change
              </Badge>
              <p className="mt-1 font-heading text-lg font-semibold">Unit 7C</p>
              <p className="text-xs text-muted-foreground">Kitchen countertop changed after completion.</p>
            </div>
          </div>
        </div>
      </Screen>
    ),
  },
  {
    id: "detector",
    label: "Detector",
    icon: Radar,
    title: "Proof the watch never sleeps",
    points: [
      "Reverie3D staff see every builder and every detector run",
      "Run it now with one button; it never double-alerts",
      "Failures are recorded with their error, not swallowed",
    ],
    screen: () => (
      <Screen path="/detector">
        <div className="flex items-center justify-between gap-3 rounded-xl bg-graphite p-4 text-ivory">
          <div>
            <p className="font-heading text-xl font-semibold">Run the detector now</p>
            <p className="text-xs text-ivory/60">Checks every project right away</p>
          </div>
          <span className="flex items-center gap-1.5 rounded-lg bg-brass px-3 py-2 text-sm font-medium text-graphite">
            <Play className="size-3.5" /> Run now
          </span>
        </div>
        <ul className="mt-4 divide-y divide-border rounded-xl bg-card ring-1 ring-border">
          {[
            { at: "Oct 21, 6:00 PM", trigger: "scheduled", status: "succeeded", flagged: 1 },
            { at: "Oct 21, 9:12 AM", trigger: "manual", status: "succeeded", flagged: 0 },
            { at: "Oct 20, 6:00 PM", trigger: "scheduled", status: "failed", flagged: 0 },
          ].map((run) => (
            <li key={run.at} className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5 text-xs">
              <span className="font-medium">{run.at}</span>
              <Badge variant="outline" className="capitalize">
                {run.trigger}
              </Badge>
              <Badge variant={run.status === "failed" ? "stalled" : "healthy"} className="capitalize">
                {run.status}
              </Badge>
              <span className="text-muted-foreground">{run.flagged} flagged</span>
            </li>
          ))}
        </ul>
      </Screen>
    ),
  },
];

/**
 * An interactive walkthrough of the four screens. Tabs follow the WAI-ARIA
 * tabs pattern (arrow keys move between them).
 */
export function ProductTour() {
  const [activeIndex, setActiveIndex] = useState(0);
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const baseId = useId();
  const active = STEPS[activeIndex];

  function handleKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const delta = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
    if (delta === 0) return;
    event.preventDefault();
    const next = (activeIndex + delta + STEPS.length) % STEPS.length;
    setActiveIndex(next);
    tabRefs.current[next]?.focus();
  }

  return (
    <div className="flex flex-col gap-10">
      <div
        role="tablist"
        aria-label="Product tour"
        onKeyDown={handleKeyDown}
        className="mx-auto grid w-full max-w-xl grid-cols-4 gap-1 rounded-2xl bg-muted/70 p-1.5 ring-1 ring-border"
      >
        {STEPS.map((step, index) => {
          const Icon = step.icon;
          const isActive = index === activeIndex;
          return (
            <button
              key={step.id}
              ref={(node) => {
                tabRefs.current[index] = node;
              }}
              type="button"
              role="tab"
              id={`${baseId}-tab-${step.id}`}
              aria-selected={isActive}
              aria-controls={`${baseId}-panel`}
              tabIndex={isActive ? 0 : -1}
              onClick={() => setActiveIndex(index)}
              className={cn(
                "relative flex h-10 min-w-0 items-center justify-center gap-2 rounded-xl px-1 text-xs font-medium whitespace-nowrap transition-colors duration-(--duration-fast) sm:px-3 sm:text-sm",
                isActive ? "text-graphite" : "text-muted-foreground hover:text-foreground",
              )}
            >
              {isActive ? (
                <motion.span
                  layoutId={`${baseId}-tour-pill`}
                  className="absolute inset-0 rounded-xl bg-card shadow-soft ring-1 ring-border"
                  transition={{ duration: 0.3, ease: EASE_OUT_QUINT }}
                />
              ) : null}
              <Icon aria-hidden="true" className="relative hidden size-4 sm:block" />
              <span className="relative">{step.label}</span>
            </button>
          );
        })}
      </div>

      <div
        role="tabpanel"
        id={`${baseId}-panel`}
        aria-labelledby={`${baseId}-tab-${active.id}`}
        className="grid items-center gap-10 lg:grid-cols-[0.8fr_1.2fr]"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={active.id}
            initial={{ opacity: 0, x: -12 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 12 }}
            transition={{ duration: DURATION_SLOW, ease: EASE_OUT_QUINT }}
            className="flex flex-col gap-5"
          >
            <p className="text-xs font-semibold tracking-[0.18em] text-brass-ink uppercase">
              Step {activeIndex + 1} of {STEPS.length}
            </p>
            <h3 className="text-4xl leading-tight font-semibold">{active.title}</h3>
            <ul className="flex flex-col gap-3">
              {active.points.map((point) => (
                <li key={point} className="flex gap-3 text-[0.9375rem] leading-relaxed text-muted-foreground">
                  <Check aria-hidden="true" className="mt-1 size-4 shrink-0 text-brass" />
                  {point}
                </li>
              ))}
            </ul>
          </motion.div>
        </AnimatePresence>
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={active.id}
            aria-hidden="true"
            initial={{ opacity: 0, y: 16, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -12, scale: 0.98 }}
            transition={{ duration: DURATION_SLOW, ease: EASE_OUT_QUINT }}
          >
            {active.screen()}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}
