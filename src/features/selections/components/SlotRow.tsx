"use client";

import { useActionState } from "react";

import {
  INITIAL_SLOT_ACTION_STATE,
  PRODUCT_NAME_MAX_LENGTH,
  type SlotActionState,
} from "../action-state";
import { changeSelection } from "../actions/change-selection";
import { clearSelection } from "../actions/clear-selection";
import { setSelection } from "../actions/set-selection";
import type { SlotView } from "../types";

type SlotRowProps = {
  slot: SlotView;
};

/**
 * One slot: the current product plus Set (empty slot) or Change and Clear.
 * The parent keys this row by slot id + lock_version, so a successful write
 * (which revalidates the page) remounts it with fresh values; a conflict does
 * not revalidate, so its message stays until the user reloads.
 */
export function SlotRow({ slot }: SlotRowProps) {
  const [setState, setAction, isSetting] = useActionState(
    setSelection,
    INITIAL_SLOT_ACTION_STATE,
  );
  const [changeState, changeAction, isChanging] = useActionState(
    changeSelection,
    INITIAL_SLOT_ACTION_STATE,
  );
  const [clearState, clearAction, isClearing] = useActionState(
    clearSelection,
    INITIAL_SLOT_ACTION_STATE,
  );

  const isPending = isSetting || isChanging || isClearing;
  const inputId = `product-${slot.id}`;
  const lockVersion = slot.selection ? String(slot.selection.lockVersion) : "";

  return (
    <tr data-testid="slot-row" data-slot-id={slot.id}>
      <th scope="row">{slot.category}</th>
      <td data-testid="slot-product">
        {slot.selection ? slot.selection.productName : <em>Not selected</em>}
      </td>
      <td>
        {slot.selection ? (
          <>
            <form action={changeAction}>
              <input type="hidden" name="slotId" value={slot.id} />
              <input type="hidden" name="lockVersion" value={lockVersion} />
              <label htmlFor={inputId}>Product for {slot.category}</label>{" "}
              <input
                id={inputId}
                name="productName"
                type="text"
                required
                maxLength={PRODUCT_NAME_MAX_LENGTH}
                defaultValue={slot.selection.productName}
              />{" "}
              <button type="submit" disabled={isPending}>
                Change
              </button>
            </form>
            <form action={clearAction}>
              <input type="hidden" name="slotId" value={slot.id} />
              <input type="hidden" name="lockVersion" value={lockVersion} />
              <button type="submit" disabled={isPending}>
                Clear
              </button>
            </form>
          </>
        ) : (
          <form action={setAction}>
            <input type="hidden" name="slotId" value={slot.id} />
            <label htmlFor={inputId}>Product for {slot.category}</label>{" "}
            <input
              id={inputId}
              name="productName"
              type="text"
              required
              maxLength={PRODUCT_NAME_MAX_LENGTH}
            />{" "}
            <button type="submit" disabled={isPending}>
              Set
            </button>
          </form>
        )}
        <SlotMessage states={[setState, changeState, clearState]} />
      </td>
    </tr>
  );
}

function SlotMessage({ states }: { states: SlotActionState[] }) {
  const error = states.find((state) => state.status === "error");
  if (!error?.message) return null;
  return (
    <p role="alert" data-testid="slot-error">
      {error.message}
    </p>
  );
}
