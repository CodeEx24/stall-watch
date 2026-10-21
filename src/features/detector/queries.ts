import "server-only";

import { cache } from "react";
import { z } from "zod";

import { requireUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import { staffMembershipRowSchema, stallRunRowSchema, type StallRunRow } from "./schemas";

/** How many runs the console lists (newest first). */
export const RUN_HISTORY_LIMIT = 50;

export const DETECTOR_LOAD_ERROR_MESSAGE = "Could not load the detector history. Please try again.";

export type DetectorConsoleResult =
  | { kind: "ok"; runs: StallRunRow[] }
  | { kind: "not-allowed" }
  | { kind: "error"; error: string };

const stallRunRowsSchema = z.array(stallRunRowSchema);
const staffMembershipRowsSchema = z.array(staffMembershipRowSchema);

/**
 * Whether the signed-in user belongs to a staff org, read from the database
 * (public.memberships joined to public.orgs, under RLS), never from JWT or
 * user metadata. Used only to choose what the page renders (UX): the real
 * walls are RLS on builder.stall_runs (p_stall_runs_select: is_staff) and the
 * is_staff check inside public.run_stall_detector_now().
 */
const isCurrentUserStaff = cache(async (userId: string): Promise<boolean | null> => {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("memberships")
    .select("org_id, orgs!inner(org_type)")
    .eq("user_id", userId)
    .eq("orgs.org_type", "staff")
    .limit(1);

  if (error) return null;
  const parsed = staffMembershipRowsSchema.safeParse(data);
  if (!parsed.success) return null;
  return parsed.data.length > 0;
});

/**
 * Whether the signed-in user is staff, for the app navigation only (shows or
 * hides the Detector link). False when unknown. Hiding a link protects
 * nothing; RLS and the RPC's is_staff check stay the walls.
 */
export async function isSignedInUserStaff(): Promise<boolean> {
  const user = await requireUser();
  return (await isCurrentUserStaff(user.id)) === true;
}

/**
 * Data for /detector: the latest detector runs, newest first, for staff.
 * Non-staff get "not-allowed" and no run query is made at all; even if one
 * were, RLS would return no rows.
 */
export async function getDetectorConsole(): Promise<DetectorConsoleResult> {
  const user = await requireUser();

  const isStaff = await isCurrentUserStaff(user.id);
  if (isStaff === null) return { kind: "error", error: DETECTOR_LOAD_ERROR_MESSAGE };
  if (!isStaff) return { kind: "not-allowed" };

  const supabase = await createClient();
  const { data, error } = await supabase
    .schema("builder")
    .from("stall_runs")
    .select(
      "id, trigger, status, started_at, finished_at, projects_flagged, alerts_created, error_message",
    )
    .order("started_at", { ascending: false })
    .order("id", { ascending: false })
    .limit(RUN_HISTORY_LIMIT);

  if (error) return { kind: "error", error: DETECTOR_LOAD_ERROR_MESSAGE };

  const parsed = stallRunRowsSchema.safeParse(data);
  if (!parsed.success) return { kind: "error", error: DETECTOR_LOAD_ERROR_MESSAGE };

  return { kind: "ok", runs: parsed.data };
}
