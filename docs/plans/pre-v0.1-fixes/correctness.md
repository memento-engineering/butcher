# Correctness fixes

Ordered by severity. Part of [index.md](index.md).

## 1. Promotion guard drops viable mutants

- Files: `lib/src/mutagens/promotion_dependence.dart` (`flipStrands`),
  consumers `equality_mutagen.dart`, `logical_mutagen.dart`.
- ADR: [0019](../../decisions/0019-static-viability-filtering.md) rejects
  guards that drop viable mutants; "guards err toward keeping a mutant".
- Problem: `flipStrands` skips a flip when *any* use of the tested variable
  anywhere in the function depends on promotion. It never checks whether
  that use is promoted *by the flipped test*.
- Repro: `final tested = x != null;` is skipped when a separate
  `if (x != null) x.abs();` exists, though the flip compiles.
- Effect: viable mutants silently never generated; MSI inflated with no
  trace in the report.
- Fix: only guard tests whose promotion scope contains the dependent use;
  simplest sound narrowing: only guard tests in condition position
  (if/while/ternary/`&&` chains), never in assignments or returns.

## 2. Interleaved stdout/stderr corrupts JSON events

- File: `lib/src/engine/dart_test_runner.dart` (both streams write into one
  `StringBuffer`).
- Problem: a stderr chunk can land mid-JSON-line; `TestEvents.parse` drops
  the corrupted line.
- Effect: a killed mutant whose only failure event was lost degrades to
  `runError`, removing it from the MSI numerator.
- Fix: buffer stdout and stderr separately; parse events from stdout only.

## 3. MSI is 100% when nothing was scoreable

- File: `lib/src/report/metrics.dart` (`_percent`, `whole == 0 ? 100`).
- ADR: [0013](../../decisions/0013-score-and-honesty-metrics.md) (honesty).
- Problem: all-timeout runs and zero-mutant runs report MSI 100% and pass
  `--threshold`; `--max-timeouts` only guards this when opted in.
- Fix: warn (or fail the gate) when the MSI denominator is zero.

## 4. README documents a non-existent coverage command

- File: `README.md` (`dart test --coverage-path=lcov.info`).
- Problem: the flag does not exist, and `dart test --coverage=<dir>` emits
  VM JSON, not lcov.
- Fix: document `dart run coverage:test_with_coverage` (writes
  `coverage/lcov.info`).

## 5. Pipeline order contradicts the documented composition

- Files: `lib/src/engine/engine.dart` (`run`),
  [decisions/index.md](../../decisions/index.md) mermaid.
- Docs say: containment → background reading → generation → viability.
- Code does: generation → viability → containment → background reading.
- Effect: a red suite aborts only after minutes of analysis.
- Fix: reorder the engine (preferred) or update the diagram; AGENTS.md
  requires docs and code to agree.
