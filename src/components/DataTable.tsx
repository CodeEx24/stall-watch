import { Stagger } from "@/components/motion/Reveal";
import { cn } from "@/lib/utils";

type Column = {
  label: string;
  isNumeric?: boolean;
};

type DataTableProps = {
  /** Screen-reader caption describing the table. */
  caption: string;
  columns: Column[];
  children: React.ReactNode;
  "data-testid"?: string;
};

/**
 * The shared data table: a real <table> on tablet and desktop that turns into
 * stacked cards below `md` (headers become per-cell <CellLabel>s), so pages
 * never scroll sideways. Rows reveal one after another.
 */
export function DataTable({ caption, columns, children, "data-testid": testId }: DataTableProps) {
  return (
    <div className="overflow-hidden rounded-2xl bg-card/80 shadow-soft ring-1 ring-border max-md:bg-transparent max-md:shadow-none max-md:ring-0">
      <table className="w-full border-collapse text-sm max-md:block" data-testid={testId}>
        <caption className="sr-only">{caption}</caption>
        <thead className="border-b border-border bg-muted/50 text-left max-md:sr-only">
          <tr className="text-xs tracking-wide text-muted-foreground uppercase">
            {columns.map((column, index) => (
              <th
                key={column.label}
                scope="col"
                className={cn(
                  "py-3 font-medium",
                  index === 0 || index === columns.length - 1 ? "px-5" : "px-4",
                  column.isNumeric && "text-right",
                )}
              >
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <Stagger
          as="tbody"
          className="divide-y divide-border max-md:flex max-md:flex-col max-md:gap-3 max-md:divide-y-0"
        >
          {children}
        </Stagger>
      </table>
    </div>
  );
}

/** Row classes: a hover tint on desktop, a card on phones. */
export const DATA_ROW_CLASS =
  "group relative transition-colors duration-(--duration-fast) hover:bg-accent/30 max-md:grid max-md:grid-cols-2 max-md:gap-4 max-md:rounded-2xl max-md:bg-card max-md:p-4 max-md:shadow-soft max-md:ring-1 max-md:ring-border";

/** Label shown above a value when the table collapses into cards on phones. */
export function CellLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="mb-1 block text-[0.6875rem] font-medium tracking-wide text-muted-foreground uppercase md:hidden">
      {children}
    </span>
  );
}
