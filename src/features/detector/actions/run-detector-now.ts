"use server";

import { revalidatePath } from "next/cache";

import { getCurrentUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import {
  RUN_DETECTOR_NOT_ALLOWED_MESSAGE,
  RUN_DETECTOR_NOW_ERROR_MESSAGE,
  type RunDetectorNowResult,
} from "../run-detector-now-state";
import { stallRunRowSchema } from "../schemas";

/** Postgres insufficient_privilege: run_stall_detector_now's answer to non-staff. */
const INSUFFICIENT_PRIVILEGE_CODE = "42501";

/**
 * "Run now": calls public.run_stall_detector_now() (POST /rest/v1/rpc/...) as
 * the signed-in user. The function's first statement checks is_staff and
 * raises 42501 otherwise, so the database, not this action or the page,
 * decides who may run the detector. No input is taken.
 *
 * A failed detector run is not an error: the RPC returns the 'failed' run
 * row, which the history then shows with its error message.
 */
export async function runDetectorNow(): Promise<RunDetectorNowResult> {
  // Server Actions are reachable by direct POST: re-check the session here.
  const user = await getCurrentUser();
  if (!user) return { ok: false, error: RUN_DETECTOR_NOW_ERROR_MESSAGE };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("run_stall_detector_now");

  if (error) {
    return {
      ok: false,
      error:
        error.code === INSUFFICIENT_PRIVILEGE_CODE
          ? RUN_DETECTOR_NOT_ALLOWED_MESSAGE
          : RUN_DETECTOR_NOW_ERROR_MESSAGE,
    };
  }

  revalidatePath("/detector");

  const parsed = stallRunRowSchema.safeParse(data);
  if (!parsed.success) return { ok: false, error: RUN_DETECTOR_NOW_ERROR_MESSAGE };

  return { ok: true, status: parsed.data.status };
}
