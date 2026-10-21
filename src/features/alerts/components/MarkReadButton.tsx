"use client";

import { useState, useTransition } from "react";

import { markAlertRead } from "../actions/mark-alert-read";

type MarkReadButtonProps = {
  alertId: string;
};

export function MarkReadButton({ alertId }: MarkReadButtonProps) {
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function handleClick() {
    setError(null);
    startTransition(async () => {
      const result = await markAlertRead(alertId);
      if (!result.ok) setError(result.error);
    });
  }

  return (
    <>
      <button type="button" onClick={handleClick} disabled={isPending} data-testid="mark-read">
        {isPending ? "Marking…" : "Mark as read"}
      </button>
      {error ? (
        <span role="alert" data-testid="mark-read-error">
          {" "}
          {error}
        </span>
      ) : null}
    </>
  );
}
