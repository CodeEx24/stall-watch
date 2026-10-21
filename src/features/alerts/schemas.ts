import { z } from "zod";

/**
 * Postgres `uuid` accepts any 8-4-4-4-12 hex value, and the seed uses
 * non-RFC ids such as 00000000-0000-0000-0000-00000000a012, which zod's
 * strict z.uuid() rejects. z.guid() checks the same shape Postgres does.
 */
const idSchema = z.guid();

/** Input of the markAlertRead Server Action: only the alert id, shape-checked. */
export const markAlertReadInputSchema = z.object({
  alertId: idSchema,
});

export type MarkAlertReadInput = z.infer<typeof markAlertReadInputSchema>;

/**
 * One row of the inbox query as PostgREST returns it (alerts plus the
 * embedded project). Parsed at the boundary because the client is untyped.
 */
export const alertRowSchema = z.object({
  id: idSchema,
  project_id: idSchema,
  kind: z.string(),
  message: z.string(),
  read_at: z.string().nullable(),
  created_at: z.string(),
  project: z.object({ name: z.string() }).nullable(),
});

export type AlertRow = z.infer<typeof alertRowSchema>;
