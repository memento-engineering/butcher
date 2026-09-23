# Polish fixes

- Status: fixed; see [index.md](index.md) for the resolution.

Release, lifecycle, and logging gaps. Part of [index.md](index.md).

## 1. Pana verification currently fails

- Files: `CHANGELOG.md`, `.github/workflows/publish.yml`.
- ADR: [0015](../../decisions/2026-08-14-full-pana-score.md) requires full points at
  all times.
- Problem: pana gives 155/160 because the changelog has no `0.1.0` heading.
  The workflow uses `--exit-code-threshold 0`, so verification exits 1.
- Fix: reconcile the unreleased-version workflow with ADR 0015 before release.

## 2. Failed startup cleanup strands the lock

- Files: `lib/src/cli/cli.dart`, `lib/src/run_workspace.dart`.
- Problem: `clean()` can throw after acquisition, but the abort path does not
  release the new lock.
- Related: coverage reading and parsing happen after acquisition and outside
  the engine's protected run block.
- Effect: later runs report a misleading active-run conflict.
- Fix: parse coverage before acquisition and release after failed startup.

## 3. `classified` events omit required properties

- File: `lib/src/engine/engine.dart` (worker-loop logging).
- ADR: [0016](../../decisions/2026-08-15-wide-event-logging.md) lists file, offset,
  operator, and replacement on the event.
- Problem: the tool event carries those values only inside the mutant id.
- Fix: add the four structured properties to the event.

## 4. `--verbose` is never colored

- Files: `lib/src/log/butcher_logger.dart`, `lib/src/cli/cli.dart`.
- ADR: [0016](../../decisions/2026-08-15-wide-event-logging.md) requires ANSI color
  when the terminal supports it.
- Problem: auto-detection requires `console == null`, but the CLI always passes
  a non-null sink.
- Fix: detect `identical(console, stdout)` or pass the color decision explicitly.
