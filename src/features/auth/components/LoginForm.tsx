"use client";

import { AlertCircle, ArrowRight, Loader2 } from "lucide-react";
import { motion } from "motion/react";
import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DURATION_BASE, EASE_OUT_QUINT } from "@/lib/motion";

import { signIn } from "../sign-in";
import { EMAIL_MAX_LENGTH, INITIAL_SIGN_IN_STATE, PASSWORD_MAX_LENGTH } from "../sign-in-state";

export function LoginForm() {
  const [state, formAction, isPending] = useActionState(signIn, INITIAL_SIGN_IN_STATE);

  return (
    <form action={formAction} noValidate className="flex flex-col gap-5">
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          inputMode="email"
          placeholder="you@yourbuilder.com"
          required
          maxLength={EMAIL_MAX_LENGTH}
          defaultValue={state.email}
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "sign-in-error" : undefined}
          className="h-11"
        />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">Password</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          maxLength={PASSWORD_MAX_LENGTH}
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "sign-in-error" : undefined}
          className="h-11"
        />
      </div>
      {state.error ? (
        <motion.p
          key={state.error}
          initial={{ opacity: 0, y: -4 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: DURATION_BASE, ease: EASE_OUT_QUINT }}
          id="sign-in-error"
          role="alert"
          data-testid="sign-in-error"
          className="flex items-center gap-2 rounded-lg bg-stalled-soft px-3 py-2.5 text-sm text-stalled"
        >
          <AlertCircle aria-hidden="true" className="size-4 shrink-0" />
          {state.error}
        </motion.p>
      ) : null}
      <Button type="submit" size="lg" disabled={isPending} className="group mt-1 w-full">
        {isPending ? (
          <>
            <Loader2 aria-hidden="true" className="animate-spin" />
            Signing in…
          </>
        ) : (
          <>
            Sign in
            <ArrowRight
              aria-hidden="true"
              className="transition-transform duration-(--duration-fast) group-hover:translate-x-0.5"
            />
          </>
        )}
      </Button>
    </form>
  );
}
