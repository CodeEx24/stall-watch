"use client";

import { motion } from "motion/react";

import { EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

/**
 * A front elevation of a house drawn in fine lines, with the finish slots a
 * builder picks (counter, tile, fixtures) marked in brass. The outline draws
 * itself once on mount; with reduced motion it simply appears.
 */
const OUTLINE_PATHS = [
  // Ground line and plinth.
  "M20 300H500",
  "M60 300V292H460V300",
  // Walls and gable roof.
  "M80 292V150H440V292",
  "M60 156L260 40L460 156",
  "M84 150L260 52L436 150",
  // Chimney.
  "M360 92V58H388V108",
  // Door with transom.
  "M232 292V212H288V292",
  "M232 200H288",
  // Windows.
  "M112 182H184V244H112Z",
  "M148 182V244",
  "M112 213H184",
  "M336 182H408V244H336Z",
  "M372 182V244",
  "M336 213H408",
  // Attic round window.
  "M260 116m-18 0a18 18 0 1 0 36 0a18 18 0 1 0 -36 0",
] as const;

const DIMENSION_PATHS = ["M80 320H440", "M80 314V326", "M440 314V326", "M480 150V292", "M474 150H486", "M474 292H486"] as const;

/** Finish-slot markers: [x, y]. */
const SLOT_MARKERS = [
  [148, 213],
  [260, 252],
  [372, 213],
  [260, 116],
] as const;

type HouseElevationProps = {
  className?: string;
  /** Line colour; defaults to ivory for dark panels. */
  tone?: "ivory" | "graphite";
};

export function HouseElevation({ className, tone = "ivory" }: HouseElevationProps) {
  const stroke = tone === "ivory" ? "var(--ivory)" : "var(--graphite)";

  return (
    <svg viewBox="0 0 520 340" fill="none" aria-hidden="true" className={cn("h-auto w-full", className)}>
      <g stroke={stroke} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" opacity="0.85">
        {OUTLINE_PATHS.map((d, index) => (
          <motion.path
            key={d}
            d={d}
            initial={{ pathLength: 0, opacity: 0 }}
            animate={{ pathLength: 1, opacity: 1 }}
            transition={{ duration: 1.4, ease: EASE_OUT_QUINT, delay: 0.15 + index * 0.06 }}
          />
        ))}
      </g>
      <g stroke="var(--brass)" strokeWidth="1" strokeDasharray="3 4" opacity="0.7">
        {DIMENSION_PATHS.map((d) => (
          <motion.path
            key={d}
            d={d}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 1.2 }}
          />
        ))}
      </g>
      {SLOT_MARKERS.map(([x, y], index) => (
        <motion.g
          key={`${x}-${y}`}
          initial={{ opacity: 0, scale: 0.6 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.4, ease: EASE_OUT_QUINT, delay: 1.4 + index * 0.12 }}
          style={{ transformOrigin: `${x}px ${y}px` }}
        >
          <circle cx={x} cy={y} r="9" fill="var(--brass)" opacity="0.18" />
          <circle cx={x} cy={y} r="3.5" fill="var(--brass)" />
        </motion.g>
      ))}
    </svg>
  );
}
