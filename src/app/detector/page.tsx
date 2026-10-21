import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";

import { DetectorConsole } from "@/features/detector/components/DetectorConsole";

export const metadata: Metadata = { title: "Detector · Stall Watch" };

export default function DetectorPage() {
  return (
    <main>
      <p>
        <Link href="/projects">← Projects</Link>
      </p>
      <h1>Stall detector</h1>
      <Suspense fallback={<p>Loading…</p>}>
        <DetectorConsole />
      </Suspense>
    </main>
  );
}
