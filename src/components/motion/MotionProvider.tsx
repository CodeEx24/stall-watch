"use client";

import { MotionConfig } from "motion/react";

/**
 * Every motion animation in the app honours the visitor's
 * prefers-reduced-motion setting: transforms are dropped, opacity stays.
 */
export function MotionProvider({ children }: { children: React.ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
