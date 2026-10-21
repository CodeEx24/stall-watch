# Stall Watch — Design System

The visual system behind every screen (STW-45). Built on **Tailwind CSS v4** and **shadcn/ui** (Radix base), customised so it does not look like a stock template. Tokens live once in `src/app/globals.css`; motion values are mirrored for the `motion` library in `src/lib/motion.ts`. Components use token names only — no one-off colours.

## Direction
A premium finish showroom: warm stone surfaces, graphite ink, brass for emphasis, a faint architectural grid. Calm by default; colour is reserved for meaning (terracotta = stalled, sage = healthy, brass = in progress / action).

## Colour
| Token | Value | Use | Contrast |
| --- | --- | --- | --- |
| `--background` | `#f6f3ec` | Page (warm stone) | — |
| `--card` | `#fffdf9` | Cards, tables, inputs | — |
| `--foreground` / `--graphite` | `#1c1917` | Text, primary buttons, dark panels | 16:1 on background |
| `--muted-foreground` | `#6b635a` | Secondary text | 5.3:1 on background |
| `--brass` | `#b08a3e` | Accent fills, rings, icons, brass buttons (graphite text) | decorative |
| `--brass-ink` | `#7a5c1c` | Brass text, eyebrows, links | 6.2:1 on white, 5.2:1 on `--brass-soft` |
| `--brass-soft` | `#f3ead6` | Brass pill backgrounds | — |
| `--stalled` | `#b4432a` | Stalled badge, errors, alarm figures | 5.6:1 on white |
| `--stalled-soft` | `#f8e6df` | Stalled/error backgrounds | — |
| `--stalled-glow` | `#e8957c` | Terracotta on graphite panels | 6:1 on graphite |
| `--healthy` | `#3f6b4f` | On track, complete, success | 6.1:1 on white |
| `--border` / `--input` | `#e5ded2` / `#ddd5c7` | Hairlines, field borders | — |
| `--ring` | `#b08a3e` | Focus ring (brass) | — |

One light theme. `dark:` utilities are bound to a `.dark` class that is never set, so they never react to the OS setting.

## Type
- **Headings:** Cormorant Garamond 500–700 (`font-heading`), tight tracking, lining numerals (`font-variant-numeric: lining-nums` is global).
- **Interface and body:** Geist (`font-sans`); numbers in tables and stats use the `tabular` utility (lining + tabular figures).
- **Mono:** Geist Mono (`font-mono`), reserved.
- Scale: page title `text-4xl`→`sm:text-5xl`; section `text-2xl`–`text-3xl`; stat figures `text-4xl`; body `text-sm`–`text-[0.9375rem]`; eyebrows `text-xs` uppercase, `tracking-[0.18em]`, brass-ink, with a 24px brass rule.
- Fonts are self-hosted by `next/font` at build time (no runtime request to Google).

## Shape and elevation
- `--radius: 0.75rem`; cards `rounded-2xl`, landing tiles `rounded-3xl`, buttons/inputs `rounded-lg`, badges `rounded-full`.
- `shadow-soft` (resting) and `shadow-lift` (hover, popovers, dark panels).
- Touch targets: buttons 40px (`default`), 36px (`sm`), 44px (`lg`); inputs 40px.

## Motion
| Token | CSS | JS (`src/lib/motion.ts`) | Use |
| --- | --- | --- | --- |
| Ease | `--ease-out-quint` `cubic-bezier(0.22,1,0.36,1)` | `EASE_OUT_QUINT` | Everything |
| Fast | `--duration-fast` 150ms | — | Hover, press, colour |
| Base | `--duration-base` 240ms | `DURATION_BASE` | Nav pill, inline feedback |
| Slow | `--duration-slow` 400ms | `DURATION_SLOW` | Entry, progress bars |

Rules: animate `transform` and `opacity` only; entry motion for server-rendered content is pure CSS (`animate-rise`, `stagger-children`) so it starts with the HTML and nothing waits on hydration; the `motion` library is used only in client components (nav pill, slot feedback, product tour, hero preview, line drawing, scroll reveals). `MotionConfig reducedMotion="user"` plus a global `prefers-reduced-motion` rule turn motion off for people who ask.

## Components
Shared (`src/components/`): `ui/*` (shadcn: Button with `brass` variant, Badge with `stalled` / `healthy` / `brass`, Input, Label, Card, Dropdown menu, Skeleton, Sonner), `DataTable` (table on desktop, stacked cards on phones, with `CellLabel` and `DATA_ROW_CLASS`), `PageHeader`, `EmptyState` (neutral / error), `StatTile`, `PageSkeleton` (`StatsSkeleton`, `ListSkeleton`), `brand/BrandMark`, `brand/HouseElevation`, `motion/Reveal` (`FadeIn`, `Stagger`, `StaggerItem`), `motion/InView`, `app-shell/*`.
Feature-level: `ProjectStatusBadge`, `StalledBadge` / `OnTrackBadge` (projects) — reused by the landing previews so marketing and product never drift.

Before adding a component, check this list (reuse-first).

## States
Every data surface has loading (skeleton matching the final layout), empty (`EmptyState`), error (`EmptyState tone="error"`, `role="alert"`), and pending (disabled control + spinner) states. Slot edits show the submitted value immediately, dimmed with a spinner, until the server answers.

## Responsive
Checked at 375, 768/954 and 1440px; no page scrolls sideways. Tables become stacked cards below `md` with per-cell labels; the nav drops to a full-width row on phones.

## Accessibility
WCAG 2.2 AA contrast (values above), visible brass focus rings, skip link, `aria-current` on the active nav item, labelled forms with `aria-invalid` / `aria-describedby` on sign-in errors, the WAI-ARIA tabs pattern (arrow keys) in the product tour, decorative SVGs `aria-hidden`. Lighthouse (mobile preset, local production build): accessibility 100 on every page.
