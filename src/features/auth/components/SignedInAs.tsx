import { requireUser } from "../queries";
import { SignOutButton } from "./SignOutButton";

/** Reads the session, so render it inside a <Suspense> boundary. */
export async function SignedInAs() {
  const user = await requireUser();

  return (
    <div>
      <p data-testid="signed-in-as">Signed in as {user.email ?? user.id}</p>
      <SignOutButton />
    </div>
  );
}
