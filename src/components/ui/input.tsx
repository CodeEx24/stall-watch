import * as React from "react"

import { cn } from "@/lib/utils"

/** shadcn Input, customised for Stall Watch (STW-45): 40px tall, warm field, brass focus. */
function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "h-10 w-full min-w-0 rounded-lg border border-input bg-card px-3 py-1 text-base shadow-[inset_0_1px_2px_rgb(28_25_23/0.04)] transition-[border-color,box-shadow] duration-(--duration-fast) ease-(--ease-out-quint) outline-none placeholder:text-muted-foreground/80 hover:border-[color-mix(in_oklch,var(--input),var(--foreground)_12%)] focus-visible:border-brass focus-visible:ring-3 focus-visible:ring-ring/25 disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-55 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/15 md:text-sm",
        className
      )}
      {...props}
    />
  )
}

export { Input }
