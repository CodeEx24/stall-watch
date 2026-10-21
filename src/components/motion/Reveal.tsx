import { cn } from "@/lib/utils";

/*
 * Entry motion for page content. These are plain server-safe elements with
 * CSS animations (animate-rise / stagger-children in globals.css), so the
 * motion starts with the HTML and content is never hidden waiting for JS.
 * Scroll-triggered reveals live in ./InView (client, motion library).
 */

type FadeInProps = React.ComponentProps<"div"> & {
  /** Seconds to wait before the fade starts. */
  delay?: number;
};

/** Fades and lifts its content in once, on load. */
export function FadeIn({ delay = 0, className, style, ...props }: FadeInProps) {
  return (
    <div
      className={cn("animate-rise", className)}
      style={{ ...style, ["--rise-delay" as string]: `${Math.round(delay * 1000)}ms` }}
      {...props}
    />
  );
}

type StaggerTag = "div" | "ul" | "tbody";

type StaggerProps<T extends StaggerTag> = { as?: T } & React.ComponentProps<T>;

/**
 * A container whose direct children rise in one after another. Renders a div,
 * ul or tbody so it can stand in for the semantic element it replaces.
 */
export function Stagger<T extends StaggerTag = "div">({ as, className, ...props }: StaggerProps<T>) {
  const Component = (as ?? "div") as React.ElementType;
  return <Component className={cn("stagger-children", className)} {...props} />;
}

type StaggerItemTag = "div" | "li" | "tr";

type StaggerItemProps<T extends StaggerItemTag> = { as?: T } & React.ComponentProps<T>;

/** One child of <Stagger>; renders a div, li or tr. The parent times it. */
export function StaggerItem<T extends StaggerItemTag = "div">({ as, ...props }: StaggerItemProps<T>) {
  const Component = (as ?? "div") as React.ElementType;
  return <Component {...props} />;
}
