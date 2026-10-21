"use server";

import { revalidatePath } from "next/cache";

import { requireUser } from "@/features/auth/queries";
import { createClient } from "@/lib/supabase/server";

import {
  CONFLICT_MESSAGE,
  GENERIC_ERROR_MESSAGE,
  type SlotActionState,
} from "../action-state";
import { clearSelectionInputSchema } from "../schemas";
import { findVisibleSlot } from "../slot-lookup";

/**
 * Clear a slot (delete its selection), guarded by the lock_version the form
 * was rendered with. The history trigger records the clear, so this is the
 * one permitted hard delete of a business row.
 */
export async function clearSelection(
  _previous: SlotActionState,
  formData: FormData,
): Promise<SlotActionState> {
  await requireUser();

  const parsed = clearSelectionInputSchema.safeParse({
    slotId: formData.get("slotId"),
    lockVersion: formData.get("lockVersion"),
  });
  if (!parsed.success) {
    return { status: "error", message: GENERIC_ERROR_MESSAGE };
  }

  const supabase = await createClient();
  const slot = await findVisibleSlot(supabase, parsed.data.slotId);
  if (!slot) return { status: "error", message: GENERIC_ERROR_MESSAGE };

  const { data, error } = await supabase
    .schema("builder")
    .from("selections")
    .delete()
    .eq("slot_id", slot.id)
    .eq("lock_version", parsed.data.lockVersion)
    .select("id");
  if (error) return { status: "error", message: GENERIC_ERROR_MESSAGE };
  // No revalidate on a conflict: keep the message until the user reloads.
  if (data.length === 0) return { status: "error", message: CONFLICT_MESSAGE };

  revalidatePath(`/projects/${slot.projectId}`);
  revalidatePath("/projects");
  return { status: "success", message: "Cleared." };
}
