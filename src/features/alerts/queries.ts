import "server-only";

import { z } from "zod";

import { requireUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import { alertRowSchema, type AlertRow } from "./schemas";

export type AlertListItem = {
  id: string;
  projectId: string;
  projectName: string | null;
  kind: string;
  message: string;
  createdAt: string;
  isUnread: boolean;
};

export type AlertListResult =
  | { ok: true; alerts: AlertListItem[] }
  | { ok: false; error: string };

export const ALERTS_LOAD_ERROR_MESSAGE = "Could not load your alerts. Please try again.";

const alertRowsSchema = z.array(alertRowSchema);

/**
 * The signed-in user's alerts, newest first (id breaks ties so the order is
 * stable when one detector run creates several alerts at the same instant).
 *
 * RLS (p_alerts_select: user_id = auth.uid()) is the wall: nobody, staff
 * included, can read another user's alerts. The user_id filter only matches
 * the (user_id, created_at desc) inbox index; it is not the security check.
 */
export async function listMyAlerts(): Promise<AlertListResult> {
  const user = await requireUser();
  const supabase = await createClient();

  const { data, error } = await supabase
    .schema("builder")
    .from("alerts")
    .select(
      "id, project_id, kind, message, read_at, created_at, project:projects!alerts_project_fk(name)",
    )
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .order("id", { ascending: false });

  if (error) return { ok: false, error: ALERTS_LOAD_ERROR_MESSAGE };

  const parsed = alertRowsSchema.safeParse(data);
  if (!parsed.success) return { ok: false, error: ALERTS_LOAD_ERROR_MESSAGE };

  return { ok: true, alerts: parsed.data.map(toListItem) };
}

function toListItem(row: AlertRow): AlertListItem {
  return {
    id: row.id,
    projectId: row.project_id,
    projectName: row.project?.name ?? null,
    kind: row.kind,
    message: row.message,
    createdAt: row.created_at,
    isUnread: row.read_at === null,
  };
}
