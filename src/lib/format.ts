/**
 * Shared, client-safe date formatting. Every time in the app is shown in UTC
 * (the footer says so), so server and browser render identical text.
 */
const DATE_FORMAT = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
  timeZone: "UTC",
});

const DATE_TIME_FORMAT = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
  timeZone: "UTC",
});

const TIME_WITH_SECONDS_FORMAT = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
  second: "2-digit",
  timeZone: "UTC",
});

const CLOCK_FORMAT = new Intl.DateTimeFormat("en-US", {
  hour: "numeric",
  minute: "2-digit",
  second: "2-digit",
  timeZone: "UTC",
});

const MONTH_DAY_FORMAT = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  timeZone: "UTC",
});

/** A timestamp -> "10:32:34 AM" (a big figure; pair it with formatMonthDay). */
export function formatClockTime(isoTimestamp: string): string {
  return CLOCK_FORMAT.format(new Date(isoTimestamp));
}

/** A timestamp -> "Oct 21". */
export function formatMonthDay(isoTimestamp: string): string {
  return MONTH_DAY_FORMAT.format(new Date(isoTimestamp));
}

/** "2026-11-14" (a date column) -> "Nov 14, 2026". */
export function formatDateOnly(isoDate: string): string {
  return DATE_FORMAT.format(new Date(`${isoDate}T00:00:00Z`));
}

/** A timestamp -> "Oct 21, 2026, 9:05 AM". */
export function formatDateTime(isoTimestamp: string): string {
  return DATE_TIME_FORMAT.format(new Date(isoTimestamp));
}

/** A timestamp -> "Oct 21, 9:05:12 AM" (run logs, where seconds matter). */
export function formatTimeWithSeconds(isoTimestamp: string): string {
  return TIME_WITH_SECONDS_FORMAT.format(new Date(isoTimestamp));
}

/** Whole seconds between two timestamps, or null if unfinished. */
export function secondsBetween(startIso: string, endIso: string | null): number | null {
  if (!endIso) return null;
  const ms = new Date(endIso).getTime() - new Date(startIso).getTime();
  return Math.max(0, Math.round(ms / 100) / 10);
}
