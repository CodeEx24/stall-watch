"use client";

import { ChevronDown, LogOut } from "lucide-react";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { signOut } from "@/features/auth/sign-out";

type UserMenuProps = {
  email: string;
  isStaff: boolean;
};

/** Initials for the avatar disc, e.g. "ana@acme.test" -> "AN". */
function getInitials(email: string): string {
  return email.replace(/[^a-z]/gi, "").slice(0, 2).toUpperCase() || "SW";
}

/** The signed-in identity and the sign-out action. */
export function UserMenu({ email, isStaff }: UserMenuProps) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className="group flex h-10 items-center gap-2.5 rounded-xl py-1 pr-2 pl-1 text-left transition-colors hover:bg-muted aria-expanded:bg-muted"
      >
        <span className="sr-only">Account menu</span>
        <span
          aria-hidden="true"
          className="grid size-8 place-items-center rounded-lg bg-graphite text-[0.6875rem] font-semibold tracking-wide text-ivory"
        >
          {getInitials(email)}
        </span>
        <span className="hidden max-w-48 flex-col leading-tight lg:flex">
          <span className="truncate text-sm font-medium" data-testid="signed-in-as">
            {email}
          </span>
          <span className="text-xs text-muted-foreground">
            {isStaff ? "Reverie3D staff" : "Builder"}
          </span>
        </span>
        <ChevronDown
          aria-hidden="true"
          className="size-4 text-muted-foreground transition-transform duration-(--duration-base) group-aria-expanded:rotate-180"
        />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-64">
        <DropdownMenuLabel className="flex flex-col gap-0.5 py-2">
          <span className="text-xs font-normal text-muted-foreground">Signed in as</span>
          <span className="truncate text-sm font-medium">{email}</span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <form action={signOut}>
          <DropdownMenuItem asChild>
            <button type="submit" className="w-full" data-testid="sign-out">
              <LogOut aria-hidden="true" />
              Sign out
            </button>
          </DropdownMenuItem>
        </form>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
