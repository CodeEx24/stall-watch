import { InView } from "@/components/motion/InView";

type SectionIntroProps = {
  eyebrow: string;
  title: string;
  description?: string;
};

/** Centred eyebrow + serif title + one line, opening each landing section. */
export function SectionIntro({ eyebrow, title, description }: SectionIntroProps) {
  return (
    <InView className="mx-auto flex max-w-2xl flex-col items-center gap-4 text-center">
      <p className="flex items-center gap-2 text-xs font-semibold tracking-[0.18em] text-brass-ink uppercase">
        <span aria-hidden="true" className="h-px w-6 bg-brass" />
        {eyebrow}
        <span aria-hidden="true" className="h-px w-6 bg-brass" />
      </p>
      <h2 className="text-4xl leading-[1.05] font-semibold sm:text-5xl">{title}</h2>
      {description ? <p className="text-base leading-relaxed text-muted-foreground">{description}</p> : null}
    </InView>
  );
}
