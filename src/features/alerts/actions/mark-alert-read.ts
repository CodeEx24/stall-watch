"use server";

import { revalidatePath } from "next/cache";

import { getCurrentUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import {
  MARK_ALERT_READ_ERROR_MESSAGE,
  type MarkAlertReadResult,
} from "../mark-alert-read-state";
import { markAlertReadInputSchema } from "../schemas";

/**
 * Marks one of the caller's alerts as read.
 *
 * - The id is only shape-checked (uuid); RLS (p_alerts_update, recipient
 *   only) decides whether the row is the caller's.
 * - The payload carries read_at and nothing else: authenticated only holds
 *   UPDATE (read_at) on builder.alerts, so any other column would fail.
 * - `.is("read_at", null)` makes it idempotent: a second click (or a replay)
 *   matches no row and keeps the first read time.
 */
export async function markAlertRead(alertId: unknown): Promise<MarkAlertReadResult> {
  const parsed = markAlertReadInputSchema.safeParse({ alertId });
  if (!parsed.success) return { ok: false, error: MARK_ALERT_READ_ERROR_MESSAGE };

  // Server Actions are reachable by direct POST: re-check the session here.
  const user = await getCurrentUser();
  if (!user) return { ok: false, error: MARK_ALERT_READ_ERROR_MESSAGE };

  const supabase = await createClient();
  const { error } = await supabase
    .schema("builder")
    .from("alerts")
    .update({ read_at: new Date().toISOString() })
    .eq("id", parsed.data.alertId)
    .is("read_at", null);

  if (error) return { ok: false, error: MARK_ALERT_READ_ERROR_MESSAGE };

  revalidatePath("/alerts");
  return { ok: true };
}
