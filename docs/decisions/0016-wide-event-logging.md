# 0016: Wide-event logging

- Status: accepted

## Context

- Debugging a failed run must not require rerunning it: a full run takes
  minutes to hours.
- Wide events (canonical log lines) put all context for one unit of work
  into one structured event instead of scattered log lines; the unit of
  work here is one mutant classification.

## Decision

- One logger (`RadLogger`) per run, created by the CLI and shared with the
  engine; both views log into it: the tool (start, report, exit) and the
  engine (generation, containments, background reading, classifications).
- Two levels only: `info` and `error`.
- CLEF (Compact Log Event Format): one JSON line per event with `@t`
  timestamp, `@mt` message template whose `{Property}` holes name the
  event's properties, and `@l` only on errors (absent means info).
- Log file at `<system temp>/rad/rad.log`; a new run deletes the previous
  file. Flushed per event, so a crash loses nothing.
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
- Mutated-run suite output is kept under `<system temp>/rad/failed-runs/`
  only for abnormal outcomes (`Timeout`, `Unviable`, `RunError`,
  `MemoryError`) for manual analysis; a new run clears the folder. These
  logs are CLEF too: a `mutant run failed` error event carrying the full
  mutation context and suite output, one `nested test error` event per
  parsed failure, all correlated with the tool log via the shared `RunId`.
  The tool log survives every outcome and reports the results.

## Rejected

- Scattered per-line printf logging: context ends up spread over lines that
  cannot be correlated.
- A logging framework dependency: two levels and one sink do not need one.
- Appending to a growing log file: old runs are noise; the report is the
  durable artifact.
