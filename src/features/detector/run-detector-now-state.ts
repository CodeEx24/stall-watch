/**
 * Client-safe pieces of the runDetectorNow contract. Kept out of the action
 * file because a "use server" file may only export async functions.
 */
export type RunDetectorNowResult =
  | { ok: true; status: "running" | "succeeded" | "failed" }
  | { ok: false; error: string };

/** Any failure, including the RPC's 42501 for non-staff: no database details. */
export const RUN_DETECTOR_NOW_ERROR_MESSAGE = "Could not run the detector. Please try again.";

/** Shown when the database rejects the caller (42501): says no more than that. */
export const RUN_DETECTOR_NOT_ALLOWED_MESSAGE = "You are not allowed to run the detector.";
