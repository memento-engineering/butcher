# Performance fixes

Part of [index.md](index.md).

## 1. Viability check is serial and duplicates analysis

- Files: `lib/src/engine/engine.dart` (`_checkViability`),
  `lib/src/engine/viability_checker.dart`,
  `lib/src/engine/mutant_generator.dart`.
- Problem:
  - every covered mutant gets its own overlay → re-resolve cycle, one at a
    time, on one thread;
  - the checker builds a fresh `AnalysisContextCollection` instead of
    reusing the one the generator just warmed over the same `lib/`;
  - the `finally` overlay-restore invalidates the file even when the next
    mutant targets the same file.
- Scale: ~174 mutants (dogfood run) means minutes before any test runs.
- Fix: share one collection between generator and checker; batch mutants
  by file; skip the restore between consecutive same-file mutants.

## 2. Containment copying wastes the walk and the workers

- File: `lib/src/engine/containment.dart` (`create`, `_excluded`).
- ADR: [0004](../../decisions/0004-shadow-copy-isolation.md) targets
  workspaces explicitly.
- Problems:
  - `list(recursive: true)` enumerates all of `.git`, `build`, and
    `.dart_tool` before discarding each entry, per worker;
  - `_excluded` checks only `segments.first`, so nested `.git`, `build`,
    and `.dart_tool` (workspace/monorepo layouts) are copied, including
    stale nested `package_config.json` files;
  - `copySync` blocks the event loop, so the N parallel `create` calls run
    effectively serially.
- Fix: recurse manually and prune excluded directories; match the default
  excludes at any depth; use async copies (or one copy cloned N times).

## 3. Arithmetic swaps generate predictably-unviable mutants

- File: `lib/src/mutagens/arithmetic_mutagen.dart` (`swaps`).
- ADR: [0019](../../decisions/0019-static-viability-filtering.md) assigns
  guards the job of minimizing unviable mutants.
- Problem: `/` always yields `double`, so `* → /` (and similar) is doomed
  in every `int` context; each one burns a viability analysis.
- Fix: type-aware swap table, e.g. `*` → `~/` when both operands are `int`.
