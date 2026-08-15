# 0016: Wide-event logging

- Status: accepted

## Context

- Debugging a failed run must not require rerunning it: a full run takes
  minutes to hours.
- Wide events (canonical log lines) put all context for one unit of work
  into one structured event instead of scattered log lines; the unit of
  work here is one mutant classification.

## Decision

- One logger (`RadLogger`) per run, created by the CLI; the engine stays
  logger-free and feeds it through its seams.
- Two levels only: `info` and `error`.
- JSON-lines log file at `<system temp>/rad.log`; a new run deletes the
  previous file. Flushed per event, so a crash loses nothing.
- Wide events, each carrying `timestamp` and a per-run `run_id`:

| Event | Context |
|---|---|
| `run_start` | tool version, Dart version, OS, project root, argv |
| `mutant` (one per mutant) | id, file, offset, operator, replacement, outcome, exit code, timed out, duration, progress |
| `run_complete` | outcome counts, MSI, covered MSI, background reading, half-life, duration, report path, exit code |
| `run_aborted` | abort message |

- Console output stays human-readable and non-verbose by default;
  `--verbose` additionally streams the structured events to the console.

## Rejected

- Scattered per-line printf logging: context ends up spread over lines that
  cannot be correlated.
- A logging framework dependency: two levels and one sink do not need one.
- Appending to a growing log file: old runs are noise; the report is the
  durable artifact.
