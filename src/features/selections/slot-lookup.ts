import "server-only";

import type { createClient } from "@/lib/supabase/server";

type SupabaseServerClient = Awaited<ReturnType<typeof createClient>>;

export type VisibleSlot = {
  id: string;
  orgId: string;
  projectId: string;
};

type SlotRow = {
  id: string;
  org_id: string;
  project_id: string;
};

/**
 * The slot as the caller can see it through RLS, or null when it is hidden
 * (another org) or missing. Server Actions take org_id and project_id from
 * here, never from the client. Plain module, not "use server", so it is not
 * exposed as an action endpoint.
 */
export async function findVisibleSlot(
  supabase: SupabaseServerClient,
  slotId: string,
): Promise<VisibleSlot | null> {
  const { data, error } = await supabase
    .schema("builder")
    .from("project_slots")
    .select("id, org_id, project_id")
    .eq("id", slotId)
    .maybeSingle()
    .overrideTypes<SlotRow, { merge: false }>();
  if (error || !data) return null;
  return { id: data.id, orgId: data.org_id, projectId: data.project_id };
}
