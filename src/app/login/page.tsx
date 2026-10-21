import { BellRing, LayoutGrid, ShieldCheck } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { BrandMark } from "@/components/brand/BrandMark";
import { HouseElevation } from "@/components/brand/HouseElevation";
import { FadeIn } from "@/components/motion/Reveal";
import { LoginForm } from "@/features/auth/components/LoginForm";

export const metadata: Metadata = { title: "Sign in · Stall Watch" };

const HIGHLIGHTS = [
  { icon: LayoutGrid, text: "Every finish slot, room by room" },
  { icon: BellRing, text: "Alerts the day a project goes quiet" },
  { icon: ShieldCheck, text: "Each builder sees only their own work" },
] as const;

export default function LoginPage() {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[1.1fr_1fr]">
      <aside className="relative hidden overflow-hidden bg-graphite p-12 text-ivory lg:flex lg:flex-col lg:justify-between">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-[0.06] [background-image:linear-gradient(to_right,var(--ivory)_1px,transparent_1px),linear-gradient(to_bottom,var(--ivory)_1px,transparent_1px)] [background-size:40px_40px]"
        />
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -bottom-40 -left-40 size-[32rem] rounded-full bg-brass/10 blur-3xl"
        />
        <Link href="/" className="relative w-fit rounded-xl" aria-label="Stall Watch home">
          <BrandMark isInverted />
        </Link>
        <div className="relative flex flex-col gap-10">
          <HouseElevation className="max-w-md" />
          <div className="flex max-w-md flex-col gap-5">
            <h2 className="text-5xl leading-[1.02] font-semibold text-ivory">
              Every finish chosen. <span className="text-brass">Every project moving.</span>
            </h2>
            <ul className="flex flex-col gap-3 text-sm text-ivory/75">
              {HIGHLIGHTS.map(({ icon: Icon, text }) => (
                <li key={text} className="flex items-center gap-3">
                  <Icon aria-hidden="true" className="size-4 text-brass" />
                  {text}
                </li>
              ))}
            </ul>
          </div>
        </div>
        <p className="relative text-xs text-ivory/50">Built for home builders and the Reverie3D team.</p>
      </aside>

      <main className="flex flex-col items-center justify-center gap-8 px-4 py-12 sm:px-8">
        {/* Outside the fade so the page paints real content immediately (FCP). */}
        <Link href="/" className="w-full max-w-sm rounded-xl lg:hidden" aria-label="Stall Watch home">
          <BrandMark />
        </Link>
        <FadeIn className="flex w-full max-w-sm flex-col gap-8">
          <div className="flex flex-col gap-2">
            <p className="flex items-center gap-2 text-xs font-semibold tracking-[0.18em] text-brass-ink uppercase">
              <span aria-hidden="true" className="h-px w-6 bg-brass" />
              Welcome back
            </p>
            <h1 className="text-5xl leading-none font-semibold">Sign in</h1>
            <p className="text-sm text-muted-foreground">Use the email and password your team gave you.</p>
          </div>
          <div className="rounded-2xl bg-card p-6 shadow-lift ring-1 ring-border sm:p-7">
            <LoginForm />
          </div>
          <p className="text-center text-xs text-muted-foreground">
            New to Stall Watch?{" "}
            <Link href="/" className="font-medium text-brass-ink underline-offset-4 hover:underline">
              See what it does
            </Link>
          </p>
        </FadeIn>
      </main>
    </div>
  );
}
