import { Compass } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { BrandMark } from "@/components/brand/BrandMark";
import { EmptyState } from "@/components/EmptyState";
import { Button } from "@/components/ui/button";

export const metadata: Metadata = { title: "Not found · Stall Watch" };

/**
 * Shown for unknown URLs and for projects the caller cannot see (another
 * builder's project renders exactly this page: no name, no hint it exists).
 */
export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl flex-col items-center justify-center gap-10 px-4 py-16">
      <BrandMark />
      <EmptyState
        icon={Compass}
        title="This page isn’t on the plans"
        description="The page may have moved, or you may not have access to it."
        action={
          <Button asChild>
            <Link href="/projects">Back to projects</Link>
          </Button>
        }
        className="w-full"
      />
    </main>
  );
}
