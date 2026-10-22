import Link from "next/link";

import { BrandMark } from "@/components/brand/BrandMark";

import { LandingNavActions } from "./LandingAuthActions";

const SECTION_LINKS = [
  { href: "#how-it-works", label: "How it works" },
  { href: "#features", label: "Features" },
  { href: "#tour", label: "Product tour" },
  { href: "#teams", label: "Who it’s for" },
] as const;

/** Frosted top bar for the public landing page. */
export function LandingNav() {
  return (
    <header className="sticky top-0 z-40 border-b border-border/60 bg-background/70 backdrop-blur-xl backdrop-saturate-150">
      <div className="mx-auto flex h-16 w-full max-w-6xl items-center gap-6 px-4 sm:px-6 lg:px-8">
        <Link href="/" className="rounded-xl" aria-label="Stall Watch home">
          <BrandMark />
        </Link>
        <nav aria-label="Sections" className="hidden md:block">
          <ul className="flex items-center gap-1">
            {SECTION_LINKS.map((link) => (
              <li key={link.href}>
                <a
                  href={link.href}
                  className="rounded-lg px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                >
                  {link.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <LandingNavActions />
        </div>
      </div>
    </header>
  );
}
