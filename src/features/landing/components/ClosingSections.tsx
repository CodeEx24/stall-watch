import { Building2, Check, ShieldCheck } from "lucide-react";

import { BrandMark } from "@/components/brand/BrandMark";
import { HouseElevation } from "@/components/brand/HouseElevation";
import { InView } from "@/components/motion/InView";

import { ClosingCtaActions } from "./LandingAuthActions";
import { SectionIntro } from "./SectionIntro";

const AUDIENCES = [
  {
    icon: Building2,
    title: "For home builders",
    points: [
      "Your projects, your rooms, your finishes — and only yours",
      "Admins get an alert the day a project stalls",
      "Every change kept, with who made it",
    ],
  },
  {
    icon: ShieldCheck,
    title: "For the Reverie3D team",
    points: [
      "See every builder and every project in one list",
      "Watch each detector run, or start one yourself",
      "Spot late changes after a project wraps",
    ],
  },
] as const;

export function AudienceSplit() {
  return (
    <section id="teams" className="scroll-mt-20 border-t border-border/70 bg-card/40 py-24 sm:py-32">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionIntro
          eyebrow="Who it’s for"
          title="One app, two sides of the build."
          description="Builders run their selections. Reverie3D keeps the whole portfolio honest."
        />
        <div className="mt-16 grid gap-5 md:grid-cols-2">
          {AUDIENCES.map((audience, index) => {
            const Icon = audience.icon;
            return (
              <InView
                key={audience.title}
                delay={index * 0.1}
                className="flex flex-col gap-6 rounded-3xl bg-card p-8 shadow-soft ring-1 ring-border"
              >
                <span className="grid size-12 place-items-center rounded-2xl bg-graphite text-brass">
                  <Icon aria-hidden="true" className="size-5" />
                </span>
                <h3 className="text-3xl font-semibold">{audience.title}</h3>
                <ul className="flex flex-col gap-3">
                  {audience.points.map((point) => (
                    <li key={point} className="flex gap-3 text-sm leading-relaxed text-muted-foreground">
                      <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-healthy" />
                      {point}
                    </li>
                  ))}
                </ul>
              </InView>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export function ClosingCta() {
  return (
    <section className="px-4 py-24 sm:px-6 sm:py-32 lg:px-8">
      <InView className="relative mx-auto grid w-full max-w-6xl items-center gap-10 overflow-hidden rounded-[2rem] bg-graphite px-8 py-14 text-ivory shadow-lift sm:px-14 lg:grid-cols-[1.2fr_1fr]">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-[0.06] [background-image:linear-gradient(to_right,var(--ivory)_1px,transparent_1px),linear-gradient(to_bottom,var(--ivory)_1px,transparent_1px)] [background-size:40px_40px]"
        />
        <div className="relative flex flex-col gap-6">
          <h2 className="text-5xl leading-[1.02] font-semibold text-ivory sm:text-6xl">
            Keep every home <span className="text-brass italic">moving.</span>
          </h2>
          <p className="max-w-md text-ivory/70">
            Sign in with the account your team gave you and see where every selection stands today.
          </p>
          <div className="flex flex-wrap gap-3">
            <ClosingCtaActions />
          </div>
        </div>
        <HouseElevation className="relative mx-auto max-w-sm" />
      </InView>
    </section>
  );
}

export function LandingFooter() {
  return (
    <footer className="border-t border-border/70">
      <div className="mx-auto flex w-full max-w-6xl flex-col gap-4 px-4 py-10 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
        <BrandMark />
        <p>Finish selections and stalled-project alerts for home builders.</p>
      </div>
    </footer>
  );
}
