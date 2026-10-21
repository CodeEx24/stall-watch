"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import { signInInputSchema } from "./schemas";
import {
  EMAIL_MAX_LENGTH,
  SIGN_IN_ERROR_MESSAGE,
  type SignInState,
} from "./sign-in-state";

/**
 * Email and password sign-in. Validates input at the boundary, signs in
 * through Supabase Auth (the session lands in cookies via the server
 * client) and redirects to /projects. Any failure returns one generic
 * message; Supabase error details are never sent to the browser.
 */
export async function signIn(
  _previous: SignInState,
  formData: FormData,
): Promise<SignInState> {
  const rawEmail = formData.get("email");
  const email = typeof rawEmail === "string" ? rawEmail.slice(0, EMAIL_MAX_LENGTH) : "";

  const parsed = signInInputSchema.safeParse({
    email: rawEmail,
    password: formData.get("password"),
  });
  if (!parsed.success) {
    return { error: SIGN_IN_ERROR_MESSAGE, email };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) {
    return { error: SIGN_IN_ERROR_MESSAGE, email };
  }

  redirect("/projects");
}
