import { ChevronLeft } from "lucide-react";
import Link from "next/link";

import { FadeIn } from "@/components/motion/Reveal";
import { cn } from "@/lib/utils";

type PageHeaderProps = {
  /** Small brass label above the title, e.g. "Portfolio". */
  eyebrow?: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  /** Buttons or badges aligned to the right on wide screens. */
  actions?: React.ReactNode;
  back?: { href: string; label: string };
  className?: string;
};

/** The title block every page opens with: one serif title, one quiet line. */
export function PageHeader({ eyebrow, title, description, actions, back, className }: PageHeaderProps) {
  return (
    <FadeIn className={cn("mb-8 flex flex-col gap-5 sm:mb-10", className)}>
      {back ? (
        <Link
          href={back.href}
          className="group inline-flex w-fit items-center gap-1 rounded-md text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ChevronLeft
            aria-hidden="true"
            className="size-4 transition-transform duration-(--duration-fast) group-hover:-translate-x-0.5"
          />
          {back.label}
        </Link>
      ) : null}
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div className="flex max-w-2xl flex-col gap-2">
          {eyebrow ? (
            <p className="flex items-center gap-2 text-xs font-semibold tracking-[0.18em] text-brass-ink uppercase">
              <span aria-hidden="true" className="h-px w-6 bg-brass" />
              {eyebrow}
            </p>
          ) : null}
          <h1 className="text-4xl leading-[1.05] font-semibold sm:text-5xl">{title}</h1>
          {description ? (
            <p className="text-[0.9375rem] leading-relaxed text-muted-foreground">{description}</p>
          ) : null}
        </div>
        {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
      </div>
    </FadeIn>
  );
}
