import type { Metadata } from "next";
import { Suspense } from "react";

import { PageHeader } from "@/components/PageHeader";
import { ListSkeleton } from "@/components/PageSkeleton";
import { AlertInbox } from "@/features/alerts/components/AlertInbox";

export const metadata: Metadata = { title: "Alerts · Stall Watch" };

export default function AlertsPage() {
  return (
    <>
      <PageHeader
        eyebrow="Inbox"
        title="Alerts"
        description="Projects that went quiet, and late changes worth a second look. Newest first."
      />
      <Suspense
        fallback={
          <div role="status">
            <span className="sr-only">Loading alerts…</span>
            <ListSkeleton rows={4} />
          </div>
        }
      >
        <AlertInbox />
      </Suspense>
    </>
  );
}
