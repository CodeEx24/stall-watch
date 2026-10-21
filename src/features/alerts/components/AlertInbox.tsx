import { BellOff, CloudOff, FolderClock } from "lucide-react";
import Link from "next/link";

import { EmptyState } from "@/components/EmptyState";
import { Stagger, StaggerItem } from "@/components/motion/Reveal";
import { Badge } from "@/components/ui/badge";
import { formatDateTime } from "@/lib/format";
import { cn } from "@/lib/utils";

import { listMyAlerts, type AlertListItem } from "../queries";
import { MarkReadButton } from "./MarkReadButton";

/** Shown before each alert so staff can tell a late change from a stall (STW-42). */
const KIND_LABELS: Record<string, string> = {
  stalled: "Stalled",
  late_change: "Late change",
};

const KIND_VARIANTS: Record<string, "stalled" | "brass"> = {
  stalled: "stalled",
  late_change: "brass",
};

/** Reads the session and the caller's alerts, so render it inside <Suspense>. */
export async function AlertInbox() {
  const result = await listMyAlerts();

  if (!result.ok) {
    return (
      <EmptyState
        icon={CloudOff}
        tone="error"
        title="Alerts could not load"
        description={result.error}
        data-testid="alerts-error"
      />
    );
  }

  if (result.alerts.length === 0) {
    return (
      <EmptyState
        icon={BellOff}
        title="All quiet"
        description="You have no alerts. When a project stalls, you’ll hear about it here first."
        data-testid="alerts-empty"
      />
    );
  }

  const unreadCount = result.alerts.filter((alert) => alert.isUnread).length;

  return (
    <div className="flex flex-col gap-4">
      <p data-testid="alerts-summary" className="flex items-center gap-2 text-sm text-muted-foreground">
        <span className="tabular font-medium text-foreground">
          {result.alerts.length} alert{result.alerts.length === 1 ? "" : "s"}
        </span>
        <span aria-hidden="true">·</span>
        <span className={cn("tabular", unreadCount > 0 && "font-medium text-stalled")}>{unreadCount} unread</span>
      </p>
      <Stagger as="ul" data-testid="alerts-list" className="flex flex-col gap-3">
        {result.alerts.map((alert) => (
          <AlertItem key={alert.id} alert={alert} />
        ))}
      </Stagger>
    </div>
  );
}

function AlertItem({ alert }: { alert: AlertListItem }) {
  return (
    <StaggerItem
      as="li"
      data-testid="alert"
      data-alert-id={alert.id}
      data-unread={alert.isUnread ? "true" : "false"}
      data-created-at={alert.createdAt}
      className={cn(
        "relative flex flex-col gap-4 overflow-hidden rounded-2xl bg-card p-5 ring-1 transition-[box-shadow,opacity] duration-(--duration-base) sm:flex-row sm:items-start sm:justify-between",
        alert.isUnread ? "shadow-soft ring-border hover:shadow-lift" : "bg-card/60 ring-border/70",
      )}
    >
      {alert.isUnread ? (
        <span aria-hidden="true" className="absolute inset-y-0 left-0 w-1 bg-gradient-to-b from-brass to-stalled" />
      ) : null}
      <div className="flex min-w-0 gap-4">
        <span
          aria-hidden="true"
          className={cn(
            "mt-0.5 grid size-10 shrink-0 place-items-center rounded-xl ring-1",
            alert.isUnread ? "bg-stalled-soft text-stalled ring-stalled/20" : "bg-muted text-muted-foreground ring-border",
          )}
        >
          <FolderClock className="size-4.5" />
        </span>
        <div className="flex min-w-0 flex-col gap-1.5">
          <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            {alert.isUnread ? (
              <Badge variant="default" data-testid="alert-new" className="h-5 px-2 text-[0.6875rem]">
                New
              </Badge>
            ) : null}
            <Badge
              variant={KIND_VARIANTS[alert.kind] ?? "outline"}
              data-testid="alert-kind"
              data-kind={alert.kind}
              className="h-5 px-2 text-[0.6875rem]"
            >
              {KIND_LABELS[alert.kind] ?? "Alert"}
            </Badge>
            <time dateTime={alert.createdAt} className="tabular">
              {formatDateTime(alert.createdAt)} UTC
            </time>
          </div>
          <p data-testid="alert-project" className="font-heading text-xl leading-snug font-semibold">
            {alert.projectName ? (
              <Link
                href={`/projects/${alert.projectId}`}
                className="underline-offset-4 transition-colors hover:text-brass-ink hover:underline"
              >
                {alert.projectName}
              </Link>
            ) : (
              "Unknown project"
            )}
          </p>
          <p
            data-testid="alert-message"
            className={cn("text-sm leading-relaxed", alert.isUnread ? "text-foreground/85" : "text-muted-foreground")}
          >
            {alert.message}
          </p>
        </div>
      </div>
      {alert.isUnread ? (
        <div className="shrink-0 sm:pl-4">
          <MarkReadButton alertId={alert.id} />
        </div>
      ) : (
        <span className="shrink-0 text-xs text-muted-foreground sm:pt-1">Read</span>
      )}
    </StaggerItem>
  );
}
