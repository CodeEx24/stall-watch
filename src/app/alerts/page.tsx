import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";

import { AlertInbox } from "@/features/alerts/components/AlertInbox";

export const metadata: Metadata = { title: "Alerts · Stall Watch" };

export default function AlertsPage() {
  return (
    <main>
      <p>
        <Link href="/projects">← Projects</Link>
      </p>
      <h1>Alerts</h1>
      <Suspense fallback={<p>Loading…</p>}>
        <AlertInbox />
      </Suspense>
    </main>
  );
}
