import { Skeleton } from "@/components/ui/skeleton";

/** Placeholder for a stat strip of `count` tiles. */
export function StatsSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4" aria-hidden="true">
      {Array.from({ length: count }, (_, index) => (
        <Skeleton key={index} className="h-[6.5rem] rounded-2xl" />
      ))}
    </div>
  );
}

/** Placeholder for a list or table of `rows` rows inside a card. */
export function ListSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-2 rounded-2xl bg-card/60 p-3 ring-1 ring-border" aria-hidden="true">
      {Array.from({ length: rows }, (_, index) => (
        <Skeleton key={index} className="h-16 rounded-xl" style={{ opacity: 1 - index * 0.12 }} />
      ))}
    </div>
  );
}

/** Title-and-content placeholder used while a whole page streams in. */
export function PageSkeleton({ label = "Loading" }: { label?: string }) {
  return (
    <div role="status" aria-live="polite" className="flex flex-col gap-8">
      <span className="sr-only">{label}…</span>
      <div className="flex flex-col gap-3" aria-hidden="true">
        <Skeleton className="h-3 w-24" />
        <Skeleton className="h-11 w-72 max-w-full" />
        <Skeleton className="h-4 w-96 max-w-full" />
      </div>
      <StatsSkeleton />
      <ListSkeleton />
    </div>
  );
}
