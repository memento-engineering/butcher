# Correctness fixes

- Status: fixed; see [index.md](index.md) for the resolution.

Ordered by severity. Part of [index.md](index.md).

## 1. Promotion guard drops viable mutants

- Files: `lib/src/mutators/promotion_dependence.dart` (`flipStrands`),
  consumers `equality_mutator.dart`, `logical_mutator.dart`.
- ADR: [0019](../../decisions/2026-08-16-static-viability-filtering.md) says guards
  err toward keeping a mutant.
- Problem: the guard scans the whole function for any promotion-dependent use.
  It does not check whether the flipped test provides that promotion.
- Effect: viable mutants disappear and inflate MSI without a report entry.
- Fix: limit the guard to uses inside the flipped test's promotion scope.

## 2. Interleaved stdout and stderr corrupt JSON events

- Files: `lib/src/engine/dart_test_runner.dart`,
  `lib/src/engine/test_events.dart`, `lib/src/engine/outcome_classifier.dart`.
- Problem: both process streams write chunks into one `StringBuffer`.
- Effect: stderr can split a stdout JSON line. The parser drops it and can
  classify a killed mutant as `runError`.
- Fix: buffer streams separately. Parse events from stdout only.

## 3. MSI is 100% when nothing is scoreable

- Files: `lib/src/report/metrics.dart`, `lib/src/cli/cli.dart`.
- ADR: [0013](../../decisions/2026-08-14-score-and-honesty-metrics.md) requires honest
  scores and a timeout gate.
- Problem: `_percent` returns 100 when its denominator is zero.
- Effect: zero-mutant, all-timeout, and all-error runs pass `--threshold`.
- Fix: make a zero denominator explicit and fail or disable the score gate.

## 4. `--threshold NaN` disables the gate

- File: `lib/src/cli/cli.dart` (`_threshold`).
- Problem: `double.tryParse('NaN')` succeeds. Both range comparisons and the
  later `metrics.msi < threshold` comparison are false.
- Effect: CI can request a threshold but never enforce it.
- Fix: reject non-finite values before checking the numeric range.

## 5. Mutant exceptions lose their evidence

- File: `lib/src/engine/engine.dart` (`_classify`).
- ADRs: [0006](../../decisions/2026-08-14-outcome-taxonomy.md),
  [0016](../../decisions/2026-08-15-wide-event-logging.md).
- Problem: `catch (_)` converts every exception into `runError` and discards
  the exception and stack trace. Results without `testRun` get no run log.
- Effect: engine bugs inflate MSI and cannot be diagnosed from retained logs.
- Fix: retain structured error details and only translate expected failures.

## 6. An in-project `BUTCHER_TEMP` copies itself

- Files: `lib/src/butcher_paths.dart`, `lib/src/engine/sandbox.dart`.
- ADR: [0004](../../decisions/2026-08-14-shadow-copy-isolation.md) allows `BUTCHER_TEMP`
  to set the exact production root.
- Problem: sandbox creates its target before recursively listing the
  project. A target below the project can enter its own source walk.
- Effect: recursive growth can consume disk and prevent the run from starting.
- Fix: reject roots inside the project or prune the resolved butcher root.

## 7. `.butcherignore` is ignored during generation

- Files: `lib/src/engine/mutant_generator.dart`,
  `lib/src/engine/sandbox.dart`.
- Problem: generation visits excluded `lib/` paths that sandbox omits.
- Effect: applying those mutants fails as `runError`, which MSI ignores.
- Fix: resolve exclusions once and share them with generation and sandbox.

## 8. `.butcherignore` is not gitignore-style

- File: `lib/src/engine/sandbox.dart` (`_consumerGlobs`).
- ADR: [0004](../../decisions/2026-08-14-shadow-copy-isolation.md) requires
  gitignore-style consumer exclusions.
- Problem: each line is passed directly to `Glob`. Negation and gitignore
  directory rules are not implemented.
- Effect: valid-looking exclusions can still copy ignored files.
- Fix: use a gitignore matcher or document and rename the simpler format.

## 9. Lcov indexing reads a different source snapshot

- Files: `lib/src/engine/lcov_coverage_provider.dart`,
  `lib/src/engine/engine.dart`.
- Problem: offsets come from generation-time `sources`, but line indexes reread
  the working tree.
- Effect: mid-run edits can route mutants using the wrong source lines.
- Fix: build coverage indexes from the captured source map.

## 10. Generator and sandbox disagree about symlinks

- Files: `lib/src/engine/mutant_generator.dart`,
  `lib/src/engine/sandbox.dart`.
- Problem: generation follows links by default. Sandbox uses
  `followLinks: false` and does not copy link entries.
- Effect: linked Dart files can generate mutants whose contained files do not
  exist, producing `runError`.
- Fix: disable link following during generation or copy links consistently.

## 11. `--fail-fast` can invalidate every mutant run

- File: `lib/src/engine/dart_test_runner.dart`.
- Problem: mutant runs always pass `--fail-fast`, introduced by `package:test`
  1.24.6. A consumer can still resolve an older compatible version.
- Effect: the baseline passes, then every mutant becomes `runError`.
- Fix: detect support once or document and enforce the minimum test version.

## 12. POSIX timeouts do not kill the process tree

- File: `lib/src/engine/dart_test_runner.dart` (`_killTree`).
- Problem: Windows uses `taskkill /T`; POSIX sends `SIGKILL` only to the direct
  `dart test` process.
- Effect: child processes from tests can survive, retain pipes, and consume
  resources after classification.
- Fix: start a process group and terminate the whole group on timeout.

## 13. Baseline runs after expensive analysis

- Files: `lib/src/engine/engine.dart`,
  [decisions/index.md](../../decisions/index.md).
- Docs compose sandbox and baseline before generation and
  viability. Code does generation and viability first.
- Effect: a red suite can waste minutes before the mandatory abort.
- Fix: run the baseline first or update the documented composition.
