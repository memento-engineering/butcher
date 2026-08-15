# 0016: Wide-event logging

- Status: accepted

## Context

- Debugging a failed run must not require rerunning it: a full run takes
  minutes to hours.
- Wide events (canonical log lines) put all context for one unit of work
  into one structured event instead of scattered log lines; the unit of
  work here is one mutant classification.

## Decision

- One tool logger (`RadLogger`) per run is created by the CLI and shared with
  the engine for start, report, exit, and orchestration events.
- Each worker appends mutant-run events to its containment log through the
  same logger implementation and CLEF schema.
- Two levels only: `info` and `error`.
- CLEF (Compact Log Event Format): one JSON line per event with `@t`
  timestamp, `@mt` message template whose `{Property}` holes name the
  event's properties, and `@l` only on errors (absent means info).
- Tool log at `<system temp>/rad/rad.log`. Startup cleanup removes the previous
  file ([0018](0018-run-workspace-lifecycle.md)). Events flush immediately.
- Wide events, each carrying a per-run `RunId` property:

| Message template | Extra properties |
|---|---|
| `starting rad {ToolVersion} on {ProjectRoot} with {Jobs} jobs` | Dart version, OS, argv |
| `classified {MutantId} as {Outcome} ({Done}/{Total})` | file, offset, operator, replacement, exit code, timed out, duration |
| `run complete: MSI {Msi}% over {MutantCount} mutants, exit {ExitCode}` | outcome counts, covered MSI, background reading, half-life, duration, report path |
| `run aborted: {Reason}` | duration |

- Console output stays human-readable and non-verbose by default;
  `--verbose` renders each event for humans: time, level, message with
  interpolated properties, ANSI-colored when the terminal supports it.
- Mutated-run suite output is kept under `<system temp>/rad/runs/`.
- The run directory is never removed. Startup cleanup removes only its
  immediate children ([0018](0018-run-workspace-lifecycle.md)).
- Each worker writes one `<containment-name>.log` file. The random containment
  name is the filename; mutation IDs never participate in path construction.
- Every executed mutant appends one wide event carrying its mutation context,
  suite output, containment name, and shared `RunId`.
- Abnormal outcomes (`Timeout`, `Unviable`, `RunError`, `MemoryError`) use error
  level. Parsed test failures remain structured nested-error events.
- Mutants with no coverage do not execute and produce no containment event.

## Rejected

- Scattered per-line printf logging: context ends up spread over lines that
  cannot be correlated.
- A logging framework dependency: two levels and one sink do not need one.
- Appending to a growing log file: old runs are noise; the report is the
  durable artifact.
- Per-mutant filenames: encoded operators collide and create excessive files.
