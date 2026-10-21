"use client"

import {
  CircleCheckIcon,
  InfoIcon,
  Loader2Icon,
  OctagonXIcon,
  TriangleAlertIcon,
} from "lucide-react"
import { Toaster as Sonner, type ToasterProps } from "sonner"

/**
 * shadcn Sonner toaster, customised for Stall Watch (STW-45): the app has one
 * light theme, so no next-themes; colours come from the design tokens.
 */
const Toaster = ({ ...props }: ToasterProps) => {
  return (
    <Sonner
      theme="light"
      position="bottom-right"
      className="toaster group"
      icons={{
        success: <CircleCheckIcon className="size-4 text-healthy" />,
        info: <InfoIcon className="size-4 text-brass-ink" />,
        warning: <TriangleAlertIcon className="size-4 text-brass-ink" />,
        error: <OctagonXIcon className="size-4 text-stalled" />,
        loading: <Loader2Icon className="size-4 animate-spin" />,
      }}
      style={
        {
          "--normal-bg": "var(--popover)",
          "--normal-text": "var(--popover-foreground)",
          "--normal-border": "var(--border)",
          "--border-radius": "var(--radius)",
        } as React.CSSProperties
      }
      toastOptions={{
        classNames: {
          toast: "cn-toast shadow-lift",
        },
      }}
      {...props}
    />
  )
}

export { Toaster }
