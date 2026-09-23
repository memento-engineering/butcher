# Performance fixes

- Status: fixed; see [index.md](index.md) for the resolution.

Part of [index.md](index.md).

## 1. Viability check is serial and duplicates analysis

- Files: `lib/src/engine/engine.dart`,
  `lib/src/engine/viability_checker.dart`,
  `lib/src/engine/mutant_generator.dart`.
- Problems:
  - each covered mutant gets one awaited overlay and resolve cycle;
  - the checker creates a second `AnalysisContextCollection`;
  - overlay restore invalidates a file before the next same-file mutant.
- Fix: share analysis state, batch by file, and avoid redundant invalidation.

## 2. Containment copying wastes the walk and workers

- File: `lib/src/engine/containment.dart` (`create`, `_excluded`).
- ADR: [0004](../../decisions/2026-08-14-shadow-copy-isolation.md) targets workspaces.
- Problems:
  - recursive listing enters excluded directories before filtering;
  - default exclusions only check the first path segment;
  - nested `.git`, `.dart_tool`, and `build` directories are copied;
  - `copySync` blocks the isolate once per file and limits worker preparation.
- Fix: recurse manually, prune directories, match excludes at any depth, and
  use asynchronous copies or clone one prepared containment.

## 3. Arithmetic swaps generate predictable compile failures

- File: `lib/src/mutagens/arithmetic_mutagen.dart` (`swaps`).
- ADR: [0019](../../decisions/2026-08-16-static-viability-filtering.md) assigns guards
  the job of minimizing unviable mutants.
- Problem: `/` always yields `double`, so swaps such as `*` to `/` cannot fill
  an `int` result slot.
- Effect: every such mutant burns a viability analysis before rejection.
- Fix: choose replacements from operand and context types, such as `~/` for
  two `int` operands.

## 4. Suite output buffering is unbounded

- Files: `lib/src/engine/dart_test_runner.dart`,
  `lib/src/engine/engine.dart` (`_logMutantRun`).
- Problem: all stdout and stderr are retained, then embedded again in a JSON
  log event.
- Effect: a print-loop mutant can exhaust rad's memory within its half-life.
- Fix: cap captured output while retaining its beginning, end, and truncation
  metadata.
