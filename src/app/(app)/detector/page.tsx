import type { Metadata } from "next";
import { Suspense } from "react";

import { PageHeader } from "@/components/PageHeader";
import { PageSkeleton } from "@/components/PageSkeleton";
import { DetectorConsole } from "@/features/detector/components/DetectorConsole";

export const metadata: Metadata = { title: "Detector · Stall Watch" };

export default function DetectorPage() {
  return (
    <>
      <PageHeader
        eyebrow="Reverie3D staff"
        title="Stall detector"
        description="The scheduled job that spots projects gone quiet and alerts their builders — every run, recorded."
      />
      <Suspense fallback={<PageSkeleton label="Loading detector" />}>
        <DetectorConsole />
      </Suspense>
    </>
  );
}
