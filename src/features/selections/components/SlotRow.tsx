"use client";

import { Check, Loader2, PencilLine, X } from "lucide-react";
import { motion } from "motion/react";
import { useActionState, useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DURATION_BASE, EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

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

/** Marks a pending clear in `pendingName`. */
const CLEARING = "";

/** The product name a form is submitting, read before the action runs. */
function readProductName(event: FormEvent<HTMLFormElement>): string {
  const value = new FormData(event.currentTarget).get("productName");
  return typeof value === "string" ? value.trim() : "";
}

/**
 * One slot: the current product plus Set (empty slot) or Change and Clear.
 * The parent keys this row by slot id + lock_version, so a successful write
 * (which revalidates the page) remounts it with fresh values; a conflict does
 * not revalidate, so its message stays until the user reloads.
 *
 * While a write is in flight the row shows the submitted value (optimistic),
 * dimmed with a spinner; the server's answer replaces it either way.
 */
export function SlotRow({ slot }: SlotRowProps) {
  const [setState, setAction, isSetting] = useActionState(setSelection, INITIAL_SLOT_ACTION_STATE);
  const [changeState, changeAction, isChanging] = useActionState(
    changeSelection,
    INITIAL_SLOT_ACTION_STATE,
  );
  const [clearState, clearAction, isClearing] = useActionState(
    clearSelection,
    INITIAL_SLOT_ACTION_STATE,
  );
  const [isEditing, setIsEditing] = useState(false);
  const [pendingName, setPendingName] = useState<string | null>(null);

  const isPending = isSetting || isChanging || isClearing;
  const inputId = `product-${slot.id}`;
  const lockVersion = slot.selection ? String(slot.selection.lockVersion) : "";

  const savedName = slot.selection?.productName ?? null;
  const shownName =
    isPending && pendingName !== null ? (pendingName === CLEARING ? null : pendingName) : savedName;
  const isFormOpen = slot.selection === null || isEditing;

  return (
    <li
      data-testid="slot-row"
      data-slot-id={slot.id}
      aria-busy={isPending}
      className="flex flex-col gap-3 px-5 py-4 transition-colors duration-(--duration-fast) hover:bg-accent/25"
    >
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div className="min-w-0 max-w-full">
          <p className="text-[0.6875rem] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
            {slot.category}
          </p>
          <p
            data-testid="slot-product"
            className={cn(
              "mt-1 flex items-center gap-2 text-[0.9375rem] font-medium transition-opacity duration-(--duration-fast)",
              isPending && "opacity-60",
            )}
          >
            {shownName !== null ? (
              <motion.span
                key={shownName}
                initial={{ opacity: 0, y: 4 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
                className="truncate"
              >
                {shownName}
              </motion.span>
            ) : (
              <span className="inline-flex items-center rounded-md border border-dashed border-input px-2 py-0.5 text-sm font-normal text-muted-foreground italic">
                Not selected
              </span>
            )}
            {isPending ? (
              <Loader2 aria-label="Saving" className="size-3.5 shrink-0 animate-spin text-brass-ink" />
            ) : null}
          </p>
        </div>

        {slot.selection && !isEditing ? (
          <div className="flex shrink-0 items-center gap-1">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setIsEditing(true)}
              disabled={isPending}
              data-testid="slot-change-open"
            >
              <PencilLine aria-hidden="true" />
              Change
            </Button>
            <form action={clearAction} onSubmit={() => setPendingName(CLEARING)}>
              <input type="hidden" name="slotId" value={slot.id} />
              <input type="hidden" name="lockVersion" value={lockVersion} />
              <Button type="submit" variant="ghost" size="sm" disabled={isPending}>
                <X aria-hidden="true" />
                Clear
              </Button>
            </form>
          </div>
        ) : null}
      </div>

      {isFormOpen ? (
        <motion.form
          key={slot.selection ? "change" : "set"}
          initial={{ opacity: 0, y: -4 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
          action={slot.selection ? changeAction : setAction}
          onSubmit={(event) => setPendingName(readProductName(event))}
          className="flex flex-col gap-2 sm:flex-row sm:items-center"
        >
          <input type="hidden" name="slotId" value={slot.id} />
          {slot.selection ? <input type="hidden" name="lockVersion" value={lockVersion} /> : null}
          <label htmlFor={inputId} className="sr-only">
            Product for {slot.category}
          </label>
          <Input
            id={inputId}
            name="productName"
            type="text"
            required
            maxLength={PRODUCT_NAME_MAX_LENGTH}
            defaultValue={slot.selection?.productName}
            placeholder={`Product for ${slot.category.toLowerCase()}`}
            autoComplete="off"
            autoFocus={isEditing}
            disabled={isPending}
            className="sm:flex-1"
          />
          <div className="flex gap-2">
            <Button
              type="submit"
              variant={slot.selection ? "default" : "brass"}
              disabled={isPending}
              className="flex-1 sm:flex-none"
            >
              {isPending ? <Loader2 aria-hidden="true" className="animate-spin" /> : <Check aria-hidden="true" />}
              {slot.selection ? "Save" : "Set"}
            </Button>
            {slot.selection ? (
              <Button type="button" variant="ghost" onClick={() => setIsEditing(false)} disabled={isPending}>
                Cancel
              </Button>
            ) : null}
          </div>
        </motion.form>
      ) : null}

      <SlotMessage states={[setState, changeState, clearState]} />
    </li>
  );
}

function SlotMessage({ states }: { states: SlotActionState[] }) {
  const error = states.find((state) => state.status === "error");
  if (!error?.message) return null;
  return (
    <motion.p
      initial={{ opacity: 0, y: -2 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
      role="alert"
      data-testid="slot-error"
      className="rounded-lg bg-stalled-soft px-3 py-2 text-sm text-stalled"
    >
      {error.message}
    </motion.p>
  );
}
