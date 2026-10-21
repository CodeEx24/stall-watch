"use client";

import { motion, type HTMLMotionProps } from "motion/react";

import { DURATION_SLOW, EASE_OUT_QUINT, RISE_DISTANCE } from "@/lib/motion";

type InViewProps = HTMLMotionProps<"div"> & {
  /** Seconds to wait after the block enters the viewport. */
  delay?: number;
};

/**
 * Fades and lifts a block in when it scrolls into view (once). For long
 * pages such as the landing page; app pages use the CSS FadeIn/Stagger.
 */
export function InView({ delay = 0, children, ...props }: InViewProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: RISE_DISTANCE * 2 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "0px 0px -80px 0px" }}
      transition={{ duration: DURATION_SLOW * 1.5, ease: EASE_OUT_QUINT, delay }}
      {...props}
    >
      {children}
    </motion.div>
  );
}
