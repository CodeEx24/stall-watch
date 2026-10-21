import type { Metadata } from "next";

import { AudienceSplit, ClosingCta, LandingFooter } from "@/features/landing/components/ClosingSections";
import { FeatureBento } from "@/features/landing/components/FeatureBento";
import { Hero } from "@/features/landing/components/Hero";
import { HowItWorks } from "@/features/landing/components/HowItWorks";
import { LandingNav } from "@/features/landing/components/LandingNav";
import { ProductTour } from "@/features/landing/components/ProductTour";
import { SectionIntro } from "@/features/landing/components/SectionIntro";

export const metadata: Metadata = {
  title: "Stall Watch — finish selections that never go quiet",
  description:
    "Room-by-room finish selections for home builders, with a daily detector that alerts your admins the moment a project stalls.",
};

/**
 * The public landing page. Fully static (no session read, no data): the
 * previews are illustrative examples built from the app's own components.
 */
export default function LandingPage() {
  return (
    <>
      <LandingNav />
      <main id="main">
        <Hero />
        <HowItWorks />
        <FeatureBento />
        <section id="tour" className="scroll-mt-20 border-t border-border/70 py-24 sm:py-32">
          <div className="mx-auto flex w-full max-w-6xl flex-col gap-14 px-4 sm:px-6 lg:px-8">
            <SectionIntro
              eyebrow="Product tour"
              title="See a day in Stall Watch."
              description="Four screens, one job. Click through the app as a builder admin and as Reverie3D staff."
            />
            <ProductTour />
          </div>
        </section>
        <AudienceSplit />
        <ClosingCta />
      </main>
      <LandingFooter />
    </>
  );
}
