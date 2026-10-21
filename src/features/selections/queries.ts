import "server-only";

import { createClient } from "@/lib/supabase/server";

import { rowIdSchema } from "./schemas";
import type { ProjectDetail, RoomView, SlotView } from "./types";

type ProjectRow = {
  id: string;
  name: string;
  org_name: string;
  status: string;
  archived_at: string | null;
  is_stalled: boolean;
};

type SlotRow = {
  id: string;
  room: string;
  category: string;
};

type SelectionRow = {
  slot_id: string;
  product_name: string;
  lock_version: number;
};

/**
 * One project with its slots grouped by room and the current selection per
 * slot, read as the signed-in user. Returns null when the id is malformed or
 * RLS hides the project (another org's id looks exactly like a missing one),
 * and reads no slots in that case. Throws on database errors.
 */
export async function getProjectDetail(rawId: string): Promise<ProjectDetail | null> {
  const parsedId = rowIdSchema.safeParse(rawId);
  if (!parsedId.success) return null;
  const projectId = parsedId.data;

  const db = (await createClient()).schema("builder");

  const { data: project, error: projectError } = await db
    .from("v_projects")
    .select("id, name, org_name, status, archived_at, is_stalled")
    .eq("id", projectId)
    .maybeSingle()
    .overrideTypes<ProjectRow, { merge: false }>();
  if (projectError) throw new Error("Could not load the project.");
  if (!project) return null;

  const { data: slots, error: slotsError } = await db
    .from("project_slots")
    .select("id, room, category")
    .eq("project_id", project.id)
    .order("room")
    .order("category")
    .overrideTypes<SlotRow[], { merge: false }>();
  if (slotsError) throw new Error("Could not load the project's slots.");

  const slotIds = slots.map((slot) => slot.id);
  let selections: SelectionRow[] = [];
  if (slotIds.length > 0) {
    const { data, error } = await db
      .from("selections")
      .select("slot_id, product_name, lock_version")
      .in("slot_id", slotIds)
      .overrideTypes<SelectionRow[], { merge: false }>();
    if (error) throw new Error("Could not load the project's selections.");
    selections = data;
  }

  return {
    id: project.id,
    name: project.name,
    orgName: project.org_name,
    status: project.status,
    archivedAt: project.archived_at,
    isStalled: project.is_stalled,
    rooms: groupByRoom(slots, selections),
  };
}

/** Slots arrive ordered by room then category; keep that order. */
function groupByRoom(slots: SlotRow[], selections: SelectionRow[]): RoomView[] {
  const selectionBySlot = new Map(selections.map((s) => [s.slot_id, s]));
  const rooms = new Map<string, SlotView[]>();

  for (const slot of slots) {
    const selection = selectionBySlot.get(slot.id);
    const view: SlotView = {
      id: slot.id,
      category: slot.category,
      selection: selection
        ? { productName: selection.product_name, lockVersion: selection.lock_version }
        : null,
    };
    const roomSlots = rooms.get(slot.room);
    if (roomSlots) roomSlots.push(view);
    else rooms.set(slot.room, [view]);
  }

  return Array.from(rooms, ([room, roomSlots]) => ({ room, slots: roomSlots }));
}
