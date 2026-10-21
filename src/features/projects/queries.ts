import "server-only";

import { requireUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import { projectRowsSchema, type ProjectRow } from "./schemas";

/** Columns the list renders; keep in sync with projectRowSchema. */
const PROJECT_LIST_COLUMNS =
  "id, org_id, org_name, name, status, selection_due_date, archived_at, slot_count, empty_slots, is_stalled";

export type ProjectListResult =
  | { ok: true; projects: ProjectRow[] }
  | { ok: false; message: string };

const LOAD_ERROR_MESSAGE = "Projects could not be loaded. Please try again.";

/**
 * Projects visible to the signed-in user, read live from builder.v_projects
 * (is_stalled is computed at query time, never cached).
 *
 * No org filter here on purpose: RLS (security_invoker view) decides what
 * the caller sees. Builders get their own orgs; staff get every org.
 * Active projects first, archived ones last, then by org and name.
 */
export async function listProjects(): Promise<ProjectListResult> {
  await requireUser();
  const supabase = await createClient();

  const { data, error } = await supabase
    .schema("builder")
    .from("v_projects")
    .select(PROJECT_LIST_COLUMNS)
    .order("archived_at", { ascending: true, nullsFirst: true })
    .order("org_name", { ascending: true })
    .order("name", { ascending: true });

  if (error) {
    console.error("listProjects failed", { code: error.code });
    return { ok: false, message: LOAD_ERROR_MESSAGE };
  }

  const parsed = projectRowsSchema.safeParse(data);
  if (!parsed.success) {
    console.error("listProjects returned an unexpected shape");
    return { ok: false, message: LOAD_ERROR_MESSAGE };
  }

  return { ok: true, projects: parsed.data };
}
