import { notFound } from "next/navigation";

import { requireUser } from "@/features/auth/queries";

import { getProjectDetail } from "../queries";
import { SlotRow } from "./SlotRow";

type ProjectDetailProps = {
  projectId: string;
};

/**
 * The project's slots grouped by room. Reads the session, so render it
 * inside a <Suspense> boundary. A malformed id or a project RLS hides
 * (another org's) renders the not-found page and nothing else: no name,
 * no slot count.
 */
export async function ProjectDetail({ projectId }: ProjectDetailProps) {
  await requireUser();
  const project = await getProjectDetail(projectId);
  if (!project) notFound();

  return (
    <article data-testid="project-detail">
      <h1>{project.name}</h1>
      <p>
        {project.orgName} · status: {project.status}
        {project.archivedAt ? " · archived" : null}
        {project.isStalled ? " · stalled" : null}
      </p>
      {project.rooms.length === 0 ? <p>This project has no slots.</p> : null}
      {project.rooms.map((room) => (
        <section key={room.room} data-testid="room">
          <h2>{room.room}</h2>
          <table>
            <thead>
              <tr>
                <th scope="col">Slot</th>
                <th scope="col">Current product</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {room.slots.map((slot) => (
                <SlotRow
                  key={`${slot.id}:${slot.selection?.lockVersion ?? "empty"}`}
                  slot={slot}
                />
              ))}
            </tbody>
          </table>
        </section>
      ))}
    </article>
  );
}
