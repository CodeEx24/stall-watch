import { z } from "zod";

import { PRODUCT_NAME_MAX_LENGTH } from "./action-state";

/**
 * Row ids are Postgres uuids. z.guid() checks the 8-4-4-4-12 hex shape
 * without the RFC version/variant bits that z.uuid() enforces: seed ids such
 * as 00000000-0000-0000-0000-00000000a014 are valid Postgres uuids but not
 * RFC 4122 v1-v8. Shape only; RLS decides whether the row is visible.
 */
export const rowIdSchema = z.guid();

export const productNameSchema = z
  .string()
  .trim()
  .min(1)
  .max(PRODUCT_NAME_MAX_LENGTH);

/**
 * The lock_version the form was rendered with, sent back as a decimal string.
 * No z.coerce: a missing field (null) would coerce to 0 and pass.
 */
export const lockVersionSchema = z
  .string()
  .regex(/^\d{1,10}$/)
  .transform(Number)
  .pipe(z.number().int().min(0).max(2_147_483_647));

export const setSelectionInputSchema = z.object({
  slotId: rowIdSchema,
  productName: productNameSchema,
});

export const changeSelectionInputSchema = z.object({
  slotId: rowIdSchema,
  productName: productNameSchema,
  lockVersion: lockVersionSchema,
});

export const clearSelectionInputSchema = z.object({
  slotId: rowIdSchema,
  lockVersion: lockVersionSchema,
});

export type SetSelectionInput = z.infer<typeof setSelectionInputSchema>;
export type ChangeSelectionInput = z.infer<typeof changeSelectionInputSchema>;
export type ClearSelectionInput = z.infer<typeof clearSelectionInputSchema>;
