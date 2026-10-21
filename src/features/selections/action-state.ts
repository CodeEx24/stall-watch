/**
 * Client-safe pieces of the slot write contract (state shape, messages,
 * limits). Kept out of the "use server" action files, which may only export
 * async functions.
 */
export type SlotActionState = {
  status: "idle" | "success" | "error";
  message: string | null;
};

export const INITIAL_SLOT_ACTION_STATE: SlotActionState = {
  status: "idle",
  message: null,
};

/** Same limit as the selections.product_name check constraint. */
export const PRODUCT_NAME_MAX_LENGTH = 200;

export const INVALID_PRODUCT_MESSAGE = `Enter a product name (1–${PRODUCT_NAME_MAX_LENGTH} characters).`;

/** Optimistic-lock miss: the row moved on since this page was rendered. */
export const CONFLICT_MESSAGE = "This slot was changed by someone else — reload.";

/** Every other failure. Never carries database or policy details. */
export const GENERIC_ERROR_MESSAGE = "Could not save this slot. Please try again.";
