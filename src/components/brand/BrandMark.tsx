import { cn } from "@/lib/utils";

type BrandMarkProps = {
  className?: string;
  /** Light wordmark for dark surfaces. */
  isInverted?: boolean;
  /** Hide the wordmark and show only the mark. */
  isCompact?: boolean;
};

/**
 * The Stall Watch mark: a house gable over a level line, drawn in brass —
 * "watching the build stay level". Pure SVG, no image request.
 */
export function BrandMark({ className, isInverted = false, isCompact = false }: BrandMarkProps) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <span
        aria-hidden="true"
        className={cn(
          "grid size-9 place-items-center rounded-xl ring-1",
          isInverted ? "bg-ivory/10 ring-ivory/15" : "bg-graphite ring-graphite/10 shadow-soft",
        )}
      >
        <svg viewBox="0 0 24 24" className="size-5" fill="none">
          <path
            d="M4 11.5 12 5l8 6.5"
            stroke="var(--brass)"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M6.5 10v8.5h11V10"
            stroke="var(--ivory)"
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path d="M9.5 15h5" stroke="var(--brass)" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
      </span>
      {isCompact ? (
        <span className="sr-only">Stall Watch</span>
      ) : (
        <span
          className={cn(
            "font-heading text-[1.35rem] leading-none font-semibold tracking-tight whitespace-nowrap",
            isInverted ? "text-ivory" : "text-graphite",
          )}
        >
          Stall Watch
        </span>
      )}
    </span>
  );
}
