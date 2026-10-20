// Deliberate lint error to prove CI fails on lint (STW-14 AC2). Reverted in the next commit.
export function lintCanary(): number {
  const unused: any = 1;
  return 2;
}
