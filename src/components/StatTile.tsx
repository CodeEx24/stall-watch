import type { LucideIcon } from "lucide-react";

import { StaggerItem } from "@/components/motion/Reveal";
import { cn } from "@/lib/utils";

type StatTileProps = {
  label: string;
  value: React.ReactNode;
  hint?: React.ReactNode;
  icon: LucideIcon;
  /** Terracotta tint for figures that need attention. */
  isAlarm?: boolean;
};

/**
 * One summary figure: label, big serif number, quiet hint. Place inside a
 * <Stagger> grid so tiles reveal in sequence.
 */
export function StatTile({ label, value, hint, icon: Icon, isAlarm = false }: StatTileProps) {
  return (
    <StaggerItem
      className={cn(
        "group relative overflow-hidden rounded-2xl bg-card p-4 shadow-soft ring-1 ring-border transition-shadow duration-(--duration-base) hover:shadow-lift sm:p-5",
        isAlarm && "ring-stalled/30",
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-xs font-medium tracking-wide text-muted-foreground uppercase">{label}</p>
        <Icon aria-hidden="true" className={cn("size-4 shrink-0", isAlarm ? "text-stalled" : "text-brass")} />
      </div>
      <div
        className={cn(
          "tabular mt-3 font-heading text-4xl leading-none font-semibold sm:text-[2.75rem]",
          isAlarm && "text-stalled",
        )}
      >
        {value}
      </div>
      {hint ? <p className="mt-2 text-xs text-muted-foreground">{hint}</p> : null}
      <span
        aria-hidden="true"
        className={cn(
          "absolute inset-x-0 bottom-0 h-0.5 origin-left scale-x-0 transition-transform duration-(--duration-slow) ease-(--ease-out-quint) group-hover:scale-x-100",
          isAlarm ? "bg-stalled" : "bg-brass",
        )}
      />
    </StaggerItem>
  );
}
