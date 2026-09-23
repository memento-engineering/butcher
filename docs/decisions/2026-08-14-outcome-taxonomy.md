---
status: accepted
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: outcome-taxonomy
  surfaces:
    - "packages/butcher/lib/src/model/outcome.dart"
    - "packages/butcher/lib/src/engine/outcome_classifier.dart"
    - "packages/butcher/lib/src/engine/engine.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0006"
---
# 0006: Outcome taxonomy

- Status: accepted

## Context

- Mature tools (pitest) model every failure mode as a result category.
- A tool exception mid-run loses all completed work.
- A budget of elapsed time cannot separate a hung run from a slow one: it is
  calibrated on an idle baseline and spent under the load the run
  itself creates. Workers contend for the machine, so a run cannot count on
  the parallelism the baseline measured; its suites effectively run one after
  another. Sized on the whole-suite reading alone, a self-run on 2026-08-21
  timed out 75 of 709 healthy mutants, 31 of them routed to the whole suite
  ([../plans/self-run-performance.md](../plans/self-run-performance.md)).
  That receipt is the whole empirical case for both rules below, and it is
  recorded here and nowhere else.

## Decision

- Every mutant result is data, never an exception:
  `Killed · Survived · NoCoverage · Timeout · Unviable · RunError ·
  MemoryError · Equivalent`.
- The full enum exists from the MVP, even for outcomes produced only by later
  stages.
- The deadline is a budget of silence, not of elapsed time: a run is timed
  out once its reporter has produced nothing for longer than the budget.
  A hung run is silent under any load; a slow one keeps streaming events.
- Budget = `max(longest gap in the baseline × 3, 10 s floor)`.
- A generous total ceiling stays as a backstop against a run that is hung
  but noisy. It no longer has to tell slow from hung, so it does not have
  to be tight.
- A routed run's deadline is whichever is longer, the selection's own serial
  cost or the whole-suite reading, both on the `× 3` rule. Taking the reading
  alone is what produced the timeouts recorded above, so the longer of the two
  is the deadline.
- Under [0021](2026-08-21-beamline-execution.md) the budget is per exposure: the
  calibration run measures every test, so a hung exposure is one that
  outlasts its own measured cost by a factor.
- `Killed`, `Survived`, and `Timeout` remain separate peer outcomes in results.
- Timeouts are inconclusive. They count as neither killed nor survived.
- `--max-timeouts` fails a run when its timeout ceiling is exceeded.
- A timed-out run is killed with everything it spawned, through the interlock
  that started it ([0022](2026-08-21-process-interlock.md)). Where no
  interlock mechanism resolves, the started pid is killed alone and the run
  says so; nothing is listed.

## Rejected

- Uncaught timeouts/OOM/crashes.
- Folding timeouts into killed or survived results.
- Deadline derived from the baseline without a floor: a near-zero
  reading collapses it.
- Deadline as a budget of total elapsed time: idle calibration, contended
  spending, and healthy mutants reported as inconclusive.
