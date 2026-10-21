"use client";

import { TriangleAlert } from "lucide-react";

import { EmptyState } from "@/components/EmptyState";
import { Button } from "@/components/ui/button";

/** Unexpected render failure inside the app shell. Never shows error details. */
export default function AppError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <EmptyState
      icon={TriangleAlert}
      tone="error"
      title="Something went wrong"
      description="This page could not be shown. Please try again in a moment."
      action={
        <Button type="button" onClick={reset}>
          Try again
        </Button>
      }
    />
  );
}
