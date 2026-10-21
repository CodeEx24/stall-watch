import type { Metadata } from "next";

import { LoginForm } from "@/features/auth/components/LoginForm";

export const metadata: Metadata = { title: "Sign in · Stall Watch" };

export default function LoginPage() {
  return (
    <main>
      <h1>Sign in</h1>
      <LoginForm />
    </main>
  );
}
