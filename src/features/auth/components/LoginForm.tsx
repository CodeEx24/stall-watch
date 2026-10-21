"use client";

import { useActionState } from "react";

import { signIn } from "../sign-in";
import {
  EMAIL_MAX_LENGTH,
  INITIAL_SIGN_IN_STATE,
  PASSWORD_MAX_LENGTH,
} from "../sign-in-state";

export function LoginForm() {
  const [state, formAction, isPending] = useActionState(
    signIn,
    INITIAL_SIGN_IN_STATE,
  );

  return (
    <form action={formAction} noValidate>
      <p>
        <label htmlFor="email">Email</label>
        <br />
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          maxLength={EMAIL_MAX_LENGTH}
          defaultValue={state.email}
        />
      </p>
      <p>
        <label htmlFor="password">Password</label>
        <br />
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          maxLength={PASSWORD_MAX_LENGTH}
        />
      </p>
      {state.error ? (
        <p role="alert" data-testid="sign-in-error">
          {state.error}
        </p>
      ) : null}
      <button type="submit" disabled={isPending}>
        {isPending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
