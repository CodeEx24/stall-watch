import { z } from "zod";

/** Project statuses, mirroring the check constraint on builder.projects. */
export const PROJECT_STATUSES = [
  "pending_kickoff",
  "selection_phase",
  "revision",
  "complete",
] as const;

/**
 * One row of builder.v_projects as PostgREST returns it. Parsed at the
 * boundary so the UI never renders an unexpected shape. Ids use z.guid()
 * (any 8-4-4-4-12 hex): seed ids such as ...0000a012 are not RFC 4122
 * versioned, which z.uuid() rejects.
 */
export const projectRowSchema = z.object({
  id: z.guid(),
  org_id: z.guid(),
  org_name: z.string(),
  name: z.string(),
  status: z.enum(PROJECT_STATUSES),
  selection_due_date: z.string().nullable(),
  archived_at: z.string().nullable(),
  slot_count: z.number().int().nonnegative(),
  empty_slots: z.number().int().nonnegative(),
  is_stalled: z.boolean(),
});

export const projectRowsSchema = z.array(projectRowSchema);

export type ProjectStatus = (typeof PROJECT_STATUSES)[number];
export type ProjectRow = z.infer<typeof projectRowSchema>;
