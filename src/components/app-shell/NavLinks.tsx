"use client";

import { Bell, LayoutGrid, Radar } from "lucide-react";
import { motion } from "motion/react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { DURATION_BASE, EASE_OUT_QUINT } from "@/lib/motion";
import { cn } from "@/lib/utils";

type NavLinksProps = {
  isStaff: boolean;
  unreadAlertCount: number | null;
};

const NAV_ITEMS = [
  { href: "/projects", label: "Projects", icon: LayoutGrid, isStaffOnly: false },
  { href: "/alerts", label: "Alerts", icon: Bell, isStaffOnly: false },
  { href: "/detector", label: "Detector", icon: Radar, isStaffOnly: true },
] as const;

/**
 * Primary navigation. The active item carries a sliding pill (shared layout
 * animation). Staff-only items are hidden for builders: a convenience only,
 * the database still refuses non-staff.
 */
export function NavLinks({ isStaff, unreadAlertCount }: NavLinksProps) {
  const pathname = usePathname();
  const items = NAV_ITEMS.filter((item) => isStaff || !item.isStaffOnly);

  return (
    <nav aria-label="Main" className="w-full md:w-auto">
      <ul className="flex items-center gap-1 rounded-xl bg-muted/70 p-1 ring-1 ring-border/70">
        {items.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);
          const Icon = item.icon;
          const showCount = item.href === "/alerts" && unreadAlertCount !== null && unreadAlertCount > 0;

          return (
            <li key={item.href} className="relative flex-1 md:flex-none">
              <Link
                href={item.href}
                aria-current={isActive ? "page" : undefined}
                data-testid={`nav-${item.label.toLowerCase()}`}
                className={cn(
                  "relative z-10 flex h-9 items-center justify-center gap-2 rounded-lg px-3.5 text-sm font-medium transition-colors duration-(--duration-fast)",
                  isActive ? "text-graphite" : "text-muted-foreground hover:text-foreground",
                )}
              >
                <Icon className="size-4" aria-hidden="true" />
                {item.label}
                {showCount ? (
                  <span
                    className="tabular grid h-5 min-w-5 place-items-center rounded-full bg-stalled px-1.5 text-[0.6875rem] font-semibold text-ivory"
                    data-testid="nav-unread-count"
                  >
                    {unreadAlertCount}
                    <span className="sr-only"> unread</span>
                  </span>
                ) : null}
              </Link>
              {isActive ? (
                <motion.span
                  layoutId="nav-active-pill"
                  aria-hidden="true"
                  className="absolute inset-0 rounded-lg bg-card shadow-soft ring-1 ring-border"
                  transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
                />
              ) : null}
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
