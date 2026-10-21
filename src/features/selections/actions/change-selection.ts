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
import { changeSelectionInputSchema } from "../schemas";
import { findVisibleSlot } from "../slot-lookup";

/**
 * Change the product on a slot with optimistic locking: the update only
 * matches when lock_version is still the one the form was rendered with
 * (the touch trigger bumps it on every update). Zero rows updated means the
 * slot moved on (changed, cleared or re-set elsewhere): ask for a reload.
 */
export async function changeSelection(
  _previous: SlotActionState,
  formData: FormData,
): Promise<SlotActionState> {
  await requireUser();

  const parsed = changeSelectionInputSchema.safeParse({
    slotId: formData.get("slotId"),
    productName: formData.get("productName"),
    lockVersion: formData.get("lockVersion"),
  });
  if (!parsed.success) {
    return { status: "error", message: INVALID_PRODUCT_MESSAGE };
  }

  const supabase = await createClient();
  const slot = await findVisibleSlot(supabase, parsed.data.slotId);
  if (!slot) return { status: "error", message: GENERIC_ERROR_MESSAGE };

  const { data, error } = await supabase
    .schema("builder")
    .from("selections")
    .update({ product_name: parsed.data.productName })
    .eq("slot_id", slot.id)
    .eq("lock_version", parsed.data.lockVersion)
    .select("id");
  if (error) return { status: "error", message: GENERIC_ERROR_MESSAGE };
  // No revalidate on a conflict: the message must stay on screen until the
  // user reloads.
  if (data.length === 0) return { status: "error", message: CONFLICT_MESSAGE };

  revalidatePath(`/projects/${slot.projectId}`);
  revalidatePath("/projects");
  return { status: "success", message: "Saved." };
}
