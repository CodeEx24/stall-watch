import { ArrowRight } from "lucide-react";
import Link from "next/link";

import { BrandMark } from "@/components/brand/BrandMark";
import { Button } from "@/components/ui/button";

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
          <Button asChild variant="ghost" className="hidden sm:inline-flex">
            <Link href="/login">Sign in</Link>
          </Button>
          <Button asChild>
            <Link href="/projects" className="group">
              <span className="sm:hidden">Open app</span>
              <span className="hidden sm:inline">Open Stall Watch</span>
              <ArrowRight
                aria-hidden="true"
                className="transition-transform duration-(--duration-fast) group-hover:translate-x-0.5"
              />
            </Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
