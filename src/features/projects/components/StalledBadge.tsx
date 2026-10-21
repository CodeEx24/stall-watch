import { Badge } from "@/components/ui/badge";

/** "Stalled" with a softly pulsing dot (static when reduced motion is on). */
export function StalledBadge() {
  return (
    <Badge variant="stalled" data-testid="stalled-badge">
      <span aria-hidden="true" className="relative flex size-1.5">
        <span className="absolute inline-flex size-full rounded-full bg-stalled motion-safe:animate-pulse-ring" />
        <span className="relative inline-flex size-1.5 rounded-full bg-stalled" />
      </span>
      Stalled
    </Badge>
  );
}

/** The calm counterpart shown when a project is moving. */
export function OnTrackBadge() {
  return (
    <Badge variant="healthy">
      <span aria-hidden="true" className="size-1.5 rounded-full bg-healthy" />
      On track
    </Badge>
  );
}
