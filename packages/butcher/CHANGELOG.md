# Changelog

## 0.1.0

- First release. butcher is a fork of the MIT-licensed `radioactive_dart`
  package by Ricardo Boss, taken with its full history, renamed, and split
  into a pub workspace; the upstream copyright notice travels with it.
- The `butcher` CLI mutates `lib/`, prints per-outcome counts, MSI and
  covered-code MSI, and writes a Stryker JSON report (`--output`).
- Mutants are generated from the analyzer's AST: arithmetic, relational,
  equality and logical operators, boolean literals, and nullability mutators
  for `??`, `?.` and injected `null`. Identity replacements are rejected and
  promotion-breaking flips are skipped rather than reported.
- Outcomes are killed, survived, noCoverage, timeout, unviable and runError.
  Timeouts are inconclusive: they enter neither score, and a timeout rate is
  printed whenever any occur. A run with no scoreable mutants reports no MSI
  and fails `--threshold`.
- Mutants that fail static analysis report as unviable without a test run, so
  a compiler failure is never counted as a kill.
- Coverage routes each mutant to the test files that cover its line, cheapest
  first, in one `--fail-fast` run. A project's own `coverage/lcov.info` is
  picked up automatically, `--coverage` supplies one, and otherwise coverage
  is collected in one extra suite run; `--no-collect-coverage` treats all code
  as covered.
- Each worker tests in its own sandbox, a temp-directory copy of the project
  holding what the repository's git listing names, so the project's own
  gitignore rules decide it. Selecting a pub workspace member copies the whole
  workspace while keeping tests, generation, coverage and report output rooted
  at that member.
- A red baseline aborts the run before generation; the green baseline's
  duration sets each mutant's deadline, so a slow selection is not a timeout.
- `--jobs` classifies in parallel, one sandbox per worker. A timed-out suite
  is killed with everything it spawned, and interrupting a run reaps every
  suite still in flight.
- `--threshold` gates on the MSI and `--max-timeouts` on timed-out mutants.
  Exit codes are 0 success, 1 gate failed, 64 usage, 70 aborted run.
- Wide-event CLEF logging: one tool log plus one log per sandbox, each
  mutant's suite output kept as a capped excerpt; `--verbose` renders the
  events on a terminal. All temp data lives under one root, redirectable with
  `BUTCHER_TEMP`, cleaned at the next run's startup under an exclusive lock.
- Published to pub.dev on 2026-09-23.
