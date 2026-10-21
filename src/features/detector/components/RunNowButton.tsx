"use client";

import { Loader2, Play } from "lucide-react";
import { motion } from "motion/react";
import { useActionState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { DURATION_BASE, EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

import { runDetectorNow } from "../actions/run-detector-now";

const STATUS_MESSAGES = {
  running: "Run started.",
  succeeded: "Run finished.",
  failed: "Run failed. See the error in the history below.",
} as const;

type RunMessage = { text: string; isError: boolean } | null;

/**
 * Staff "Run now". A form action rather than onClick, so a click that lands
 * before hydration is queued and replayed by React instead of being lost.
 */
async function runAndDescribe(): Promise<RunMessage> {
  const result = await runDetectorNow();
  const message = result.ok
    ? { text: STATUS_MESSAGES[result.status], isError: result.status === "failed" }
    : { text: result.error, isError: true };
  if (message.isError) toast.error(message.text);
  else toast.success(message.text);
  return message;
}

export function RunNowButton() {
  const [message, formAction, isPending] = useActionState(runAndDescribe, null);

  return (
    <form action={formAction} className="flex flex-col gap-2 sm:items-end">
      <Button type="submit" variant="brass" size="lg" disabled={isPending} data-testid="run-now">
        {isPending ? <Loader2 aria-hidden="true" className="animate-spin" /> : <Play aria-hidden="true" />}
        {isPending ? "Running…" : "Run now"}
      </Button>
      {message && !isPending ? (
        <motion.span
          key={message.text}
          initial={{ opacity: 0, y: -2 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
          role={message.isError ? "alert" : "status"}
          data-testid="run-now-message"
          className={cn("text-sm", message.isError ? "text-stalled-glow" : "text-ivory/80")}
        >
          {message.text}
        </motion.span>
      ) : null}
    </form>
  );
}
