"use server";

import { revalidatePath } from "next/cache";

import { requireUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import {
  CONFLICT_MESSAGE,
  GENERIC_ERROR_MESSAGE,
  INVALID_PRODUCT_MESSAGE,
  type SlotActionState,
} from "../action-state";
import { setSelectionInputSchema } from "../schemas";
import { findVisibleSlot } from "../slot-lookup";

/** Postgres unique_violation: the slot already has a selection. */
const UNIQUE_VIOLATION = "23505";

/**
 * Set a product on an empty slot (insert). org_id comes from the slot row the
 * caller can see through RLS, never from the form; selected_by and the
 * history row (actor_kind builder/staff) are written by database triggers.
 */
export async function setSelection(
  _previous: SlotActionState,
  formData: FormData,
): Promise<SlotActionState> {
  await requireUser();

  const parsed = setSelectionInputSchema.safeParse({
    slotId: formData.get("slotId"),
    productName: formData.get("productName"),
  });
  if (!parsed.success) {
    return { status: "error", message: INVALID_PRODUCT_MESSAGE };
  }

  const supabase = await createClient();
  const slot = await findVisibleSlot(supabase, parsed.data.slotId);
  if (!slot) return { status: "error", message: GENERIC_ERROR_MESSAGE };

  const { error } = await supabase
    .schema("builder")
    .from("selections")
    .insert({
      org_id: slot.orgId,
      slot_id: slot.id,
      product_name: parsed.data.productName,
    });
  if (error) {
    // Someone else set this slot after the page was rendered.
    if (error.code === UNIQUE_VIOLATION) {
      return { status: "error", message: CONFLICT_MESSAGE };
    }
    return { status: "error", message: GENERIC_ERROR_MESSAGE };
  }

  revalidatePath(`/projects/${slot.projectId}`);
  revalidatePath("/projects");
  return { status: "success", message: "Saved." };
}
