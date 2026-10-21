import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"

/*
 * shadcn Button, customised for Stall Watch (STW-45): 40px+ touch targets,
 * graphite primary with a brass focus ring, a press that settles rather than
 * jumps, and transitions on colour/shadow/transform only.
 */
const buttonVariants = cva(
  "group/button relative inline-flex shrink-0 items-center justify-center gap-2 rounded-lg border border-transparent bg-clip-padding text-sm font-medium tracking-[-0.005em] whitespace-nowrap transition-[color,background-color,border-color,box-shadow,transform] duration-(--duration-fast) ease-(--ease-out-quint) outline-none select-none focus-visible:ring-3 focus-visible:ring-ring/45 active:not-aria-[haspopup]:scale-[0.98] disabled:pointer-events-none disabled:opacity-55 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-soft hover:bg-primary/90 hover:shadow-lift",
        brass:
          "bg-brass text-graphite shadow-soft hover:bg-[color-mix(in_oklch,var(--brass),white_12%)] hover:shadow-lift",
        outline:
          "border-border bg-card/70 text-foreground shadow-[0_1px_0_rgb(28_25_23/0.03)] hover:border-brass/50 hover:bg-card aria-expanded:bg-muted",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_6%)]",
        ghost:
          "text-muted-foreground hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground",
        destructive:
          "bg-stalled-soft text-stalled hover:bg-[color-mix(in_oklch,var(--stalled-soft),var(--stalled)_10%)] focus-visible:ring-destructive/25",
        link: "h-auto px-0 text-brass-ink underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4",
        sm: "h-9 gap-1.5 rounded-md px-3 text-[0.8125rem]",
        lg: "h-11 px-5 text-[0.9375rem]",
        icon: "size-10",
        "icon-sm": "size-9 rounded-md",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
