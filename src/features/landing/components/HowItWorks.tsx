import { BellRing, ClipboardList, PencilRuler } from "lucide-react";

import { InView } from "@/components/motion/InView";

import { SectionIntro } from "./SectionIntro";

const STEPS = [
  {
    icon: ClipboardList,
    title: "Lay out the home",
    body: "Each project lists its rooms and the finish slots inside them — Kitchen countertop, Primary bath tile, Entry lighting.",
  },
  {
    icon: PencilRuler,
    title: "Builders choose finishes",
    body: "Your team sets, changes or clears a product per slot. Every change is saved and written to the project’s history.",
  },
  {
    icon: BellRing,
    title: "Stall Watch keeps watch",
    body: "Each day a detector checks every project in selection. Seven quiet days and the builder’s admins get one clear alert.",
  },
] as const;

export function HowItWorks() {
  return (
    <section id="how-it-works" className="scroll-mt-20 border-y border-border/70 bg-card/40 py-24 sm:py-32">
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <SectionIntro
          eyebrow="How it works"
          title="From blank slots to a finished spec — without the chasing."
          description="Three steps, no spreadsheets, no reminder emails written by hand."
        />
        <ol className="relative mt-16 grid gap-6 md:grid-cols-3">
          <span
            aria-hidden="true"
            className="absolute top-7 right-[16%] left-[16%] hidden h-px bg-gradient-to-r from-transparent via-brass/50 to-transparent md:block"
          />
          {STEPS.map((step, index) => {
            const Icon = step.icon;
            return (
              <li key={step.title}>
                <InView delay={index * 0.12} className="relative flex flex-col items-start gap-4 md:items-center md:text-center">
                  <span className="relative grid size-14 place-items-center rounded-2xl bg-graphite text-brass shadow-lift">
                    <Icon aria-hidden="true" className="size-6" />
                    <span className="absolute -top-2 -right-2 grid size-6 place-items-center rounded-full bg-brass text-[0.6875rem] font-semibold text-graphite">
                      {index + 1}
                    </span>
                  </span>
                  <h3 className="text-2xl font-semibold">{step.title}</h3>
                  <p className="max-w-xs text-sm leading-relaxed text-muted-foreground">{step.body}</p>
                </InView>
              </li>
            );
          })}
        </ol>
      </div>
    </section>
  );
}
