/**
 * Shared, client-safe pieces of the sign-in contract. Kept out of
 * sign-in.ts because a "use server" file may only export async functions.
 */
export type SignInState = {
  error: string | null;
  email: string;
};

export const INITIAL_SIGN_IN_STATE: SignInState = { error: null, email: "" };

/** One message for every failure: never reveal which part was wrong. */
export const SIGN_IN_ERROR_MESSAGE = "Invalid email or password.";

export const EMAIL_MAX_LENGTH = 254;

/**
 * Supabase Auth hashes passwords with bcrypt, which only uses the first
 * 72 bytes, and rejects longer passwords at sign-up, so nothing longer can
 * be a valid password.
 */
export const PASSWORD_MAX_LENGTH = 72;
