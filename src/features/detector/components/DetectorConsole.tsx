import type { StallRunRow } from "../schemas";
import { getDetectorConsole, RUN_HISTORY_LIMIT } from "../queries";
import { RunNowButton } from "./RunNowButton";

const TIME_FORMAT = new Intl.DateTimeFormat("en-US", {
  dateStyle: "medium",
  timeStyle: "medium",
  timeZone: "UTC",
});

const CELL_STYLE = { borderBottom: "1px solid #d4d4d4", padding: "4px 8px", textAlign: "left" } as const;

/** Reads the session, staff status and run history, so render it inside <Suspense>. */
export async function DetectorConsole() {
  const result = await getDetectorConsole();

  if (result.kind === "not-allowed") {
    return (
      <section data-testid="detector-not-allowed">
        <h2>Staff only</h2>
        <p>This page is only available to Reverie3D staff.</p>
      </section>
    );
  }

  if (result.kind === "error") {
    return (
      <p role="alert" data-testid="detector-error">
        {result.error}
      </p>
    );
  }

  return (
    <>
      <RunNowButton />
      <h2>Run history</h2>
      {result.runs.length === 0 ? (
        <p data-testid="runs-empty">The detector has not run yet.</p>
      ) : (
        <>
          <p>Up to the latest {RUN_HISTORY_LIMIT} runs, newest first. Times in UTC.</p>
          <table data-testid="runs-table" style={{ borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th style={CELL_STYLE}>Started</th>
                <th style={CELL_STYLE}>Finished</th>
                <th style={CELL_STYLE}>Trigger</th>
                <th style={CELL_STYLE}>Status</th>
                <th style={CELL_STYLE}>Projects flagged</th>
                <th style={CELL_STYLE}>Alerts created</th>
                <th style={CELL_STYLE}>Error</th>
              </tr>
            </thead>
            <tbody>
              {result.runs.map((run) => (
                <RunRow key={run.id} run={run} />
              ))}
            </tbody>
          </table>
        </>
      )}
    </>
  );
}

function RunRow({ run }: { run: StallRunRow }) {
  return (
    <tr
      data-testid="run"
      data-run-id={run.id}
      data-trigger={run.trigger}
      data-status={run.status}
      data-started-at={run.started_at}
    >
      <td style={CELL_STYLE}>
        <time dateTime={run.started_at}>{TIME_FORMAT.format(new Date(run.started_at))}</time>
      </td>
      <td style={CELL_STYLE}>
        {run.finished_at ? (
          <time dateTime={run.finished_at}>{TIME_FORMAT.format(new Date(run.finished_at))}</time>
        ) : (
          "—"
        )}
      </td>
      <td style={CELL_STYLE}>{run.trigger}</td>
      <td style={{ ...CELL_STYLE, fontWeight: run.status === "failed" ? 700 : 400 }}>{run.status}</td>
      <td style={CELL_STYLE}>{run.projects_flagged}</td>
      <td style={CELL_STYLE}>{run.alerts_created}</td>
      <td style={CELL_STYLE} data-testid="run-error">
        {run.error_message ?? ""}
      </td>
    </tr>
  );
}
