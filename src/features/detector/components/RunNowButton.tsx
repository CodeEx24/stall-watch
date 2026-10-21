"use client";

import { useState, useTransition } from "react";

import { runDetectorNow } from "../actions/run-detector-now";

const STATUS_MESSAGES = {
  running: "Run started.",
  succeeded: "Run finished.",
  failed: "Run failed. See the error in the history below.",
} as const;

export function RunNowButton() {
  const [isPending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ text: string; isError: boolean } | null>(null);

  function handleClick() {
    setMessage(null);
    startTransition(async () => {
      const result = await runDetectorNow();
      setMessage(
        result.ok
          ? { text: STATUS_MESSAGES[result.status], isError: result.status === "failed" }
          : { text: result.error, isError: true },
      );
    });
  }

  return (
    <p>
      <button type="button" onClick={handleClick} disabled={isPending} data-testid="run-now">
        {isPending ? "Running…" : "Run now"}
      </button>
      {message ? (
        <span role={message.isError ? "alert" : "status"} data-testid="run-now-message">
          {" "}
          {message.text}
        </span>
      ) : null}
    </p>
  );
}
