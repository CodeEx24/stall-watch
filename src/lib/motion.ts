/**
 * Motion tokens for the `motion` library. They mirror the CSS tokens in
 * src/app/globals.css (--ease-out-quint, --duration-*) so CSS transitions and
 * JS animations share one feel. Only transform and opacity are animated.
 */
export const EASE_OUT_QUINT = [0.22, 1, 0.36, 1] as const;

/** Seconds, as the motion library expects. */
export const DURATION_BASE = 0.24;
export const DURATION_SLOW = 0.4;

/** Distance (px) content travels while it fades in. */
export const RISE_DISTANCE = 10;
