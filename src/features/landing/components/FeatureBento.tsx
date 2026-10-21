import { Check, History, Lock, Radar, Smartphone } from "lucide-react";

import { InView } from "@/components/motion/InView";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

import { SectionIntro } from "./SectionIntro";

function Tile({
  className,
  delay = 0,
  isDark = false,
  children,
}: {
  className?: string;
  delay?: number;
  isDark?: boolean;
  children: React.ReactNode;
}) {
  return (
    <InView
      delay={delay}
      className={cn(
        "group relative flex flex-col gap-5 overflow-hidden rounded-3xl p-7 ring-1 transition-shadow duration-(--duration-base) hover:shadow-lift",
        isDark ? "bg-graphite text-ivory ring-graphite" : "bg-card shadow-soft ring-border",
        className,
      )}
    >
      {children}
    </InView>
  );
}

function TileText({ title, body, isDark = false }: { title: string; body: string; isDark?: boolean }) {
  return (
    <div className="flex flex-col gap-2">
      <h3 className={cn("text-2xl font-semibold", isDark && "text-ivory")}>{title}</h3>
      <p className={cn("text-sm leading-relaxed", isDark ? "text-ivory/70" : "text-muted-foreground")}>{body}</p>
    </div>
  );
}

const EXAMPLE_SLOTS = [
  { category: "Countertop", product: "Calacatta Gold quartz" },
  { category: "Backsplash", product: "Zellige tile, chalk" },
  { category: "Cabinet hardware", product: null },
] as const;

export function FeatureBento() {
  return (
    <section id="features" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionIntro
          eyebrow="Features"
          title="Everything a selection phase needs. Nothing it doesn’t."
          description="A focused tool for one job: getting every finish chosen on time."
        />
        <div className="mt-16 grid gap-5 md:grid-cols-6">
          <Tile className="md:col-span-4">
            <TileText
              title="Room-by-room selections"
              body="Every slot shows what’s chosen and what’s still open. Set, change or clear in one step — conflicting edits are caught, never silently overwritten."
            />
            <div aria-hidden="true" className="overflow-hidden rounded-2xl ring-1 ring-border">
              <div className="flex items-center justify-between border-b border-border bg-muted/50 px-4 py-2.5">
                <span className="font-heading text-lg font-semibold">Kitchen</span>
                <Badge variant="outline">2/3 selected</Badge>
              </div>
              <ul className="divide-y divide-border">
                {EXAMPLE_SLOTS.map((slot) => (
                  <li key={slot.category} className="flex items-center justify-between gap-3 bg-card px-4 py-3">
                    <div>
                      <p className="text-[0.625rem] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
                        {slot.category}
                      </p>
                      {slot.product ? (
                        <p className="text-sm font-medium">{slot.product}</p>
                      ) : (
                        <p className="mt-0.5 w-fit rounded-md border border-dashed border-input px-2 text-sm text-muted-foreground italic">
                          Not selected
                        </p>
                      )}
                    </div>
                    {slot.product ? (
                      <span className="flex items-center gap-1 text-xs text-healthy">
                        <Check className="size-3.5" /> Chosen
                      </span>
                    ) : (
                      <span className="rounded-lg bg-brass px-3 py-1.5 text-xs font-medium text-graphite">Set</span>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          </Tile>

          <Tile className="md:col-span-2" isDark delay={0.08}>
            <span className="grid size-11 place-items-center rounded-xl bg-ivory/10 ring-1 ring-ivory/15">
              <Radar aria-hidden="true" className="size-5 text-brass" />
            </span>
            <TileText
              isDark
              title="A detector that never forgets"
              body="Runs every day on its own. Staff can run it on demand and see every run — including the ones that failed."
            />
            <div aria-hidden="true" className="mt-auto flex flex-col gap-2">
              {[
                { status: "succeeded", flagged: 1 },
                { status: "succeeded", flagged: 0 },
                { status: "failed", flagged: 0 },
              ].map((run, index) => (
                <div key={index} className="flex items-center justify-between rounded-xl bg-ivory/5 px-3 py-2 text-xs ring-1 ring-ivory/10">
                  <span className="text-ivory/60">Run {3 - index}</span>
                  <span className={run.status === "failed" ? "text-stalled-glow" : "text-brass"}>{run.status}</span>
                  <span className="text-ivory/60">{run.flagged} flagged</span>
                </div>
              ))}
            </div>
          </Tile>

          <Tile className="md:col-span-2" delay={0.04}>
            <span className="grid size-11 place-items-center rounded-xl bg-brass-soft text-brass-ink ring-1 ring-brass/25">
              <Lock aria-hidden="true" className="size-5" />
            </span>
            <TileText
              title="Walls in the database"
              body="Each builder sees only their own projects. The rule lives in the database itself, so no screen or bug can leak another builder’s work."
            />
          </Tile>

          <Tile className="md:col-span-2" delay={0.1}>
            <span className="grid size-11 place-items-center rounded-xl bg-brass-soft text-brass-ink ring-1 ring-brass/25">
              <History aria-hidden="true" className="size-5" />
            </span>
            <TileText
              title="A history that can’t be rewritten"
              body="Every set, change and clear is recorded, along with who made it. Late changes after a project wraps raise their own alert."
            />
          </Tile>

          <Tile className="md:col-span-2" delay={0.16}>
            <span className="grid size-11 place-items-center rounded-xl bg-brass-soft text-brass-ink ring-1 ring-brass/25">
              <Smartphone aria-hidden="true" className="size-5" />
            </span>
            <TileText
              title="At the desk or on site"
              body="Designed for a laptop in the sales office and a phone in a half-built kitchen — same clarity on both."
            />
            <div aria-hidden="true" className="mt-auto flex items-center gap-2 text-xs text-muted-foreground">
              <Check className="size-3.5 text-healthy" /> Works in the browser — nothing to install
            </div>
          </Tile>
        </div>
      </div>
    </section>
  );
}
