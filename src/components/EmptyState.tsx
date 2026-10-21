import type { LucideIcon } from "lucide-react";

import { cn } from "@/lib/utils";

type EmptyStateProps = {
  icon: LucideIcon;
  title: string;
  description?: React.ReactNode;
  action?: React.ReactNode;
  /** "error" tints the icon terracotta and announces the message. */
  tone?: "neutral" | "error";
  className?: string;
  "data-testid"?: string;
};

/** A calm, centred panel for "nothing here yet", "not allowed" and load errors. */
export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  tone = "neutral",
  className,
  "data-testid": testId,
}: EmptyStateProps) {
  const isError = tone === "error";

  return (
    <div
      role={isError ? "alert" : undefined}
      data-testid={testId}
      className={cn(
        "flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card/60 px-6 py-14 text-center",
        className,
      )}
    >
      <span
        aria-hidden="true"
        className={cn(
          "mb-1 grid size-12 place-items-center rounded-2xl ring-1",
          isError ? "bg-stalled-soft text-stalled ring-stalled/20" : "bg-brass-soft text-brass-ink ring-brass/25",
        )}
      >
        <Icon className="size-5" />
      </span>
      <h2 className="text-2xl font-semibold">{title}</h2>
      {description ? (
        <p className="max-w-md text-sm leading-relaxed text-muted-foreground">{description}</p>
      ) : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}
