"use client";

import { Check, Loader2 } from "lucide-react";
import { useActionState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";

import { markAlertRead } from "../actions/mark-alert-read";

type MarkReadButtonProps = {
  alertId: string;
};

/**
 * A form action rather than onClick, so a click that lands before hydration
 * is queued and replayed by React instead of being lost.
 */
export function MarkReadButton({ alertId }: MarkReadButtonProps) {
  const [error, formAction, isPending] = useActionState(async (): Promise<string | null> => {
    const result = await markAlertRead(alertId);
    if (!result.ok) return result.error;
    toast.success("Alert marked as read");
    return null;
  }, null);

  return (
    <form action={formAction} className="flex flex-col items-start gap-2 sm:items-end">
      <Button type="submit" variant="outline" size="sm" disabled={isPending} data-testid="mark-read">
        {isPending ? <Loader2 aria-hidden="true" className="animate-spin" /> : <Check aria-hidden="true" />}
        {isPending ? "Marking…" : "Mark as read"}
      </Button>
      {error && !isPending ? (
        <span role="alert" data-testid="mark-read-error" className="text-xs text-stalled">
          {error}
        </span>
      ) : null}
    </form>
  );
}
