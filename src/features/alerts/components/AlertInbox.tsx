import Link from "next/link";

import { listMyAlerts, type AlertListItem } from "../queries";
import { MarkReadButton } from "./MarkReadButton";

const CREATED_AT_FORMAT = new Intl.DateTimeFormat("en-US", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "UTC",
});

/** Shown before each alert so staff can tell a late change from a stall (STW-42). */
const KIND_LABELS: Record<string, string> = {
  stalled: "Stalled",
  late_change: "Late change",
};

/** Reads the session and the caller's alerts, so render it inside <Suspense>. */
export async function AlertInbox() {
  const result = await listMyAlerts();

  if (!result.ok) {
    return (
      <p role="alert" data-testid="alerts-error">
        {result.error}
      </p>
    );
  }

  if (result.alerts.length === 0) {
    return <p data-testid="alerts-empty">You have no alerts.</p>;
  }

  const unreadCount = result.alerts.filter((alert) => alert.isUnread).length;

  return (
    <>
      <p data-testid="alerts-summary">
        {result.alerts.length} alert{result.alerts.length === 1 ? "" : "s"}, {unreadCount} unread
      </p>
      <ul data-testid="alerts-list" style={{ listStyle: "none", padding: 0 }}>
        {result.alerts.map((alert) => (
          <AlertItem key={alert.id} alert={alert} />
        ))}
      </ul>
    </>
  );
}

function AlertItem({ alert }: { alert: AlertListItem }) {
  return (
    <li
      data-testid="alert"
      data-alert-id={alert.id}
      data-unread={alert.isUnread ? "true" : "false"}
      data-created-at={alert.createdAt}
      style={{
        borderLeft: alert.isUnread ? "4px solid #b45309" : "4px solid #d4d4d4",
        fontWeight: alert.isUnread ? 700 : 400,
        margin: "0 0 12px",
        padding: "4px 12px",
      }}
    >
      {alert.isUnread ? <strong data-testid="alert-new">New · </strong> : null}
      <span data-testid="alert-kind" data-kind={alert.kind}>
        {KIND_LABELS[alert.kind] ?? "Alert"}
      </span>
      {" · "}
      <span data-testid="alert-project">
        {alert.projectName ? (
          <Link href={`/projects/${alert.projectId}`}>{alert.projectName}</Link>
        ) : (
          "Unknown project"
        )}
      </span>
      {" · "}
      <time dateTime={alert.createdAt}>{CREATED_AT_FORMAT.format(new Date(alert.createdAt))} UTC</time>
      <br />
      <span data-testid="alert-message">{alert.message}</span>
      {alert.isUnread ? (
        <>
          <br />
          <MarkReadButton alertId={alert.id} />
        </>
      ) : null}
    </li>
  );
}
