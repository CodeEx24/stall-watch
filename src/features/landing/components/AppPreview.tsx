"use client";

import { BellRing, Check, LayoutGrid } from "lucide-react";
import { motion } from "motion/react";

import { BrandMark } from "@/components/brand/BrandMark";
import { ProjectStatusBadge } from "@/features/projects/components/ProjectStatusBadge";
import { OnTrackBadge, StalledBadge } from "@/features/projects/components/StalledBadge";
import { EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

/** Example rows for the hero preview. Illustrative only — not live data. */
const EXAMPLE_PROJECTS = [
  { name: "Lot 14", builder: "Acme Homes", status: "selection_phase", open: 6, total: 12, isStalled: true },
  { name: "Unit 5A", builder: "Acme Homes", status: "selection_phase", open: 3, total: 10, isStalled: false },
  { name: "Lot 9", builder: "Birch & Co.", status: "revision", open: 1, total: 8, isStalled: false },
  { name: "Unit 7C", builder: "Birch & Co.", status: "complete", open: 0, total: 9, isStalled: false },
] as const;

const FLOAT = {
  animate: { y: [0, -8, 0] },
  transition: { duration: 6, repeat: Infinity, ease: "easeInOut" as const },
};

/**
 * A miniature of the real app for the landing hero: the projects table,
 * a stall alert and a saved selection, built from the same components.
 */
export function AppPreview() {
  return (
    <div className="relative mx-auto w-full max-w-xl lg:max-w-none" aria-hidden="true">
      <motion.div
        initial={{ opacity: 0, y: 24, rotateX: 8 }}
        animate={{ opacity: 1, y: 0, rotateX: 0 }}
        transition={{ duration: 0.9, ease: EASE_OUT_QUINT, delay: 0.2 }}
        style={{ transformPerspective: 1200 }}
        className="overflow-hidden rounded-2xl bg-card shadow-[0_40px_80px_-30px_rgb(28_25_23/0.35)] ring-1 ring-border"
      >
        <div className="flex items-center gap-2 border-b border-border bg-muted/60 px-4 py-3">
          <span className="size-2.5 rounded-full bg-stalled/50" />
          <span className="size-2.5 rounded-full bg-brass/60" />
          <span className="size-2.5 rounded-full bg-healthy/50" />
          <span className="ml-3 truncate rounded-md bg-card px-3 py-1 text-[0.6875rem] text-muted-foreground ring-1 ring-border">
            stall-watch.app/projects
          </span>
        </div>
        <div className="flex items-center justify-between border-b border-border px-4 py-3">
          <BrandMark className="scale-90 origin-left" />
          <span className="flex items-center gap-1 rounded-lg bg-muted px-2.5 py-1.5 text-xs font-medium">
            <LayoutGrid className="size-3.5" /> Projects
          </span>
        </div>
        <div className="p-4">
          <p className="font-heading text-2xl font-semibold">Projects</p>
          <div className="mt-3 grid grid-cols-3 gap-2">
            {[
              { label: "Active", value: "4" },
              { label: "Stalled", value: "1", isAlarm: true },
              { label: "Open slots", value: "10" },
            ].map((stat) => (
              <div key={stat.label} className="rounded-xl bg-background/70 p-3 ring-1 ring-border">
                <p className="text-[0.625rem] tracking-wide text-muted-foreground uppercase">{stat.label}</p>
                <p className={cn("mt-1 font-heading text-2xl font-semibold", stat.isAlarm && "text-stalled")}>
                  {stat.value}
                </p>
              </div>
            ))}
          </div>
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-xl ring-1 ring-border">
            {EXAMPLE_PROJECTS.map((project, index) => (
              <motion.li
                key={project.name}
                initial={{ opacity: 0, x: -8 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, ease: EASE_OUT_QUINT, delay: 0.6 + index * 0.08 }}
                className={cn(
                  "flex items-center gap-3 bg-card px-3 py-2.5 text-xs",
                  project.isStalled && "shadow-[inset_3px_0_0_var(--stalled)]",
                )}
              >
                <div className="w-20 shrink-0">
                  <p className="font-heading text-base leading-tight font-semibold">{project.name}</p>
                  <p className="truncate text-[0.625rem] text-muted-foreground">{project.builder}</p>
                </div>
                <div className="hidden sm:block">
                  <ProjectStatusBadge status={project.status} />
                </div>
                <div className="flex flex-1 flex-col gap-1">
                  <span className="text-[0.625rem] text-muted-foreground">
                    {project.open} of {project.total} open
                  </span>
                  <span className="h-1 overflow-hidden rounded-full bg-muted">
                    <span
                      className={cn("block h-full origin-left rounded-full", project.isStalled ? "bg-stalled" : "bg-brass")}
                      style={{ transform: `scaleX(${(project.total - project.open) / project.total})` }}
                    />
                  </span>
                </div>
                {project.isStalled ? <StalledBadge /> : <OnTrackBadge />}
              </motion.li>
            ))}
          </ul>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, ease: EASE_OUT_QUINT, delay: 1.1 }}
        className="absolute -bottom-8 -left-4 w-64 sm:-left-10"
      >
        <motion.div
          {...FLOAT}
          className="flex gap-3 rounded-2xl bg-card p-4 shadow-lift ring-1 ring-border"
        >
          <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-stalled-soft text-stalled">
            <BellRing className="size-4" />
          </span>
          <div className="min-w-0">
            <p className="text-[0.625rem] font-semibold tracking-wide text-stalled uppercase">Stall alert</p>
            <p className="font-heading text-lg leading-tight font-semibold">Lot 14 has gone quiet</p>
            <p className="text-xs text-muted-foreground">No builder activity in 7 days</p>
          </div>
        </motion.div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, ease: EASE_OUT_QUINT, delay: 1.3 }}
        className="absolute -top-6 -right-2 hidden w-60 sm:block lg:-right-8"
      >
        <motion.div
          animate={{ y: [0, 8, 0] }}
          transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
          className="rounded-2xl bg-graphite p-4 text-ivory shadow-lift"
        >
          <p className="text-[0.625rem] font-semibold tracking-[0.14em] text-brass uppercase">Kitchen · Countertop</p>
          <p className="mt-1 font-heading text-lg leading-tight font-semibold">Calacatta Gold quartz</p>
          <p className="mt-2 flex items-center gap-1.5 text-xs text-ivory/70">
            <Check className="size-3.5 text-brass" /> Saved · recorded in history
          </p>
        </motion.div>
      </motion.div>
    </div>
  );
}
