/**
 * Client-safe pieces of the markAlertRead contract. Kept out of the action
 * file because a "use server" file may only export async functions.
 */
export type MarkAlertReadResult = { ok: true } | { ok: false; error: string };

/** One message for every failure; database details never reach the browser. */
export const MARK_ALERT_READ_ERROR_MESSAGE = "Could not mark the alert as read. Please try again.";
