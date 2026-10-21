"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

/** Ends the session on this device, clears the auth cookies, back to /login. */
export async function signOut(): Promise<void> {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect("/login");
}
