import { z } from "zod";

import { EMAIL_MAX_LENGTH, PASSWORD_MAX_LENGTH } from "./sign-in-state";

export const signInInputSchema = z.object({
  email: z.string().trim().max(EMAIL_MAX_LENGTH).pipe(z.email()),
  password: z.string().min(1).max(PASSWORD_MAX_LENGTH),
});

export type SignInInput = z.infer<typeof signInInputSchema>;
