# Polish fixes

Small deviations and robustness gaps. Part of [index.md](index.md).

## 1. `--verbose` is never colored

- Files: `lib/src/log/rad_logger.dart` (auto-detect requires
  `console == null`), `lib/src/cli/cli.dart` (always passes `console:`).
- ADR: [0016](../../decisions/0016-wide-event-logging.md) requires ANSI
  color when the terminal supports it.
- Fix: detect on `identical(console, stdout)`, or pass `colors` from the CLI.

## 2. `classified` event misses ADR-mandated properties

- File: `lib/src/engine/engine.dart` (worker loop logging).
- ADR 0016 lists file, offset, operator, replacement on the event; the code
  logs them only inside the mutant id string.

## 3. Failed startup cleanup strands the lock

- Files: `lib/src/cli/cli.dart` (`acquire(...)..clean()`),
  `lib/src/run_workspace.dart`.
- Problem: `clean()` throwing after acquisition exits 70 without release;
  later runs abort with a misleading "another run holds the lock" message.
- Related: the lcov read/parse runs after acquisition and outside the try;
  parse coverage before taking the lock.

## 4. Generator follows symlinks

- File: `lib/src/engine/mutant_generator.dart` (`listSync(recursive: true)`).
- A symlink cycle in `lib/` hangs generation; containment copying already
  passes `followLinks: false`.

## 5. `.radignore` is ignored by the generator

- Files: `lib/src/engine/mutant_generator.dart`,
  `lib/src/engine/containment.dart` (`_consumerGlobs`).
- Excluding a `lib/` subtree still generates mutants there; they fail
  `Containment.apply` and pollute results as `runError`.

## 6. Lcov line index reads the current working tree

- File: `lib/src/engine/lcov_coverage_provider.dart` (`_indexOf`).
- Offsets refer to generation-time `sources`, but the index is built from
  the file on disk; mid-run edits skew coverage decisions the rest of the
  pipeline defends against.

## 7. Unbounded suite output buffering

- Files: `lib/src/engine/dart_test_runner.dart` (one `StringBuffer`),
  `lib/src/engine/engine.dart` (`_logMutantRun` embeds full output).
- A mutant that turns a test into a print loop can OOM rad within its
  half-life. Cap captured output.

## 8. `--fail-fast` breaks on older `package:test`

- File: `lib/src/engine/dart_test_runner.dart`.
- The background reading passes (no flag), then every mutant run fails on
  the unknown option and reports `runError`. Detect support once, or
  document the minimum `package:test` version.
