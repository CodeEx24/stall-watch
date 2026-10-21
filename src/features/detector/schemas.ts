import { z } from "zod";

/**
 * Postgres `uuid` accepts any 8-4-4-4-12 hex value, and seed/fixture ids are
 * not always RFC-versioned, which zod's strict z.uuid() rejects. z.guid()
 * checks the same shape Postgres does.
 */
const idSchema = z.guid();

/** Values of builder.stall_runs.trigger / .status (text + check in the DB). */
export const STALL_RUN_TRIGGERS = ["scheduled", "manual"] as const;
export const STALL_RUN_STATUSES = ["running", "succeeded", "failed"] as const;

/**
 * One builder.stall_runs row as PostgREST returns it, from the history query
 * and from the run_stall_detector_now RPC. Parsed at the boundary because the
 * client is untyped; extra columns (created_at, lock_version, ...) are dropped.
 */
export const stallRunRowSchema = z.object({
  id: idSchema,
  trigger: z.enum(STALL_RUN_TRIGGERS),
  status: z.enum(STALL_RUN_STATUSES),
  started_at: z.string(),
  finished_at: z.string().nullable(),
  projects_flagged: z.number().int().nonnegative(),
  alerts_created: z.number().int().nonnegative(),
  error_message: z.string().nullable(),
});

export type StallRunRow = z.infer<typeof stallRunRowSchema>;

/** The caller's own membership in a staff org (see isCurrentUserStaff). */
export const staffMembershipRowSchema = z.object({
  org_id: idSchema,
});
