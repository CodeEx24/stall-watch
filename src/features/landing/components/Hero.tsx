import { ArrowRight, PlayCircle } from "lucide-react";
import Link from "next/link";

import { FadeIn } from "@/components/motion/Reveal";
import { Button } from "@/components/ui/button";

import { AppPreview } from "./AppPreview";

const PROOF_POINTS = [
  { value: "7 days", label: "of quiet flags a project" },
  { value: "Daily", label: "automatic stall check" },
  { value: "1 alert", label: "per stall, never spam" },
] as const;

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute top-[-20%] left-1/2 h-[42rem] w-[60rem] -translate-x-1/2 rounded-full bg-brass/10 blur-3xl"
      />
      <div className="relative mx-auto grid w-full max-w-6xl items-center gap-16 px-4 pt-16 pb-24 sm:px-6 sm:pt-24 lg:grid-cols-[1fr_1.05fr] lg:gap-12 lg:px-8 lg:pb-32">
        <div className="flex flex-col gap-7">
          <FadeIn>
            <p className="inline-flex w-fit items-center gap-2 rounded-full bg-card/80 py-1 pr-3 pl-1 text-xs font-medium text-muted-foreground shadow-soft ring-1 ring-border">
              <span className="rounded-full bg-graphite px-2 py-0.5 text-[0.6875rem] text-ivory">New</span>
              Finish selections &amp; stall alerts for home builders
            </p>
          </FadeIn>
          <FadeIn delay={0.08}>
            <h1 className="text-[3.25rem] leading-[0.98] font-semibold sm:text-7xl">
              No project goes quiet <span className="text-brass-ink italic">on your watch.</span>
            </h1>
          </FadeIn>
          <FadeIn delay={0.16}>
            <p className="max-w-lg text-lg leading-relaxed text-muted-foreground">
              Stall Watch keeps every home’s finish selections in one calm place — countertops, tile, fixtures,
              room by room — and tells your admins the moment a project stops moving.
            </p>
          </FadeIn>
          <FadeIn delay={0.24} className="flex flex-wrap items-center gap-3">
            <Button asChild size="lg">
              <Link href="/projects" className="group">
                Open Stall Watch
                <ArrowRight
                  aria-hidden="true"
                  className="transition-transform duration-(--duration-fast) group-hover:translate-x-0.5"
                />
              </Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <a href="#tour">
                <PlayCircle aria-hidden="true" />
                Take the tour
              </a>
            </Button>
          </FadeIn>
          <FadeIn delay={0.32}>
            <dl className="mt-2 grid max-w-md grid-cols-3 gap-4 border-t border-border pt-6">
              {PROOF_POINTS.map((point) => (
                <div key={point.label} className="flex flex-col gap-1">
                  <dt className="order-2 text-xs leading-snug text-muted-foreground">{point.label}</dt>
                  <dd className="order-1 font-heading text-2xl font-semibold">{point.value}</dd>
                </div>
              ))}
            </dl>
          </FadeIn>
        </div>
        <AppPreview />
      </div>
    </section>
  );
}
