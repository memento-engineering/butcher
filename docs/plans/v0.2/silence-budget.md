# 1. Deadline as a budget of silence

- Status: pending
- Decision: [0006](../../decisions/2026-08-14-outcome-taxonomy.md)

Goal: a run is timed out when its reporter goes quiet, not when it takes long.
A hung run is silent under any load; a slow one keeps streaming events.

## Today

| Where | Behaviour |
|---|---|
| `engine.dart` `deadlineFor` | `max(background × 3, 10 s floor)` |
| `engine.dart` `_deadlineFor` | routed: `max(selection sum, background) × 3` |
| `dart_test_runner.dart` | `process.exitCode.timeout(...)`, one elapsed budget |

Calibrated idle, spent under 8-way contention. Three self-runs paid for that
([../self-run-performance.md](../self-run-performance.md)): 17, 75, then 16
timeouts, the best of them at a 830 s median before a mutant was called
inconclusive.

## Questions to answer

1. What is the longest silent gap in a green reading of this package, against
   the suite's own span? If one slow test dominates the gap distribution, the
   budget is that test and the `× 3` buys nothing.
2. Do reporter `time` fields advance while a suite loads? A suite sits in
   `loading X` before its first event; loading is either inside the budget or
   needs its own.
3. How much does the longest gap inflate under 8 workers versus an idle
   reading? This is exactly what killed the elapsed-time budget.
4. What total ceiling never fires on a healthy mutant and still bounds a run
   that is hung but noisy? Confirm or replace: `reading × 30`, floor 10 min.
5. Does stderr count as a heartbeat? A suite printing to stderr is alive and
   produces no reporter event.

## Steps

- Record, on the streaming path in `dart_test_runner.dart`, the gap between
  consecutive event `time` values and between their arrival wall-clocks. Log
  the distribution for a green reading and for a contended routed run.
- Replace the exit-code timeout with a resettable idle timer plus the total
  ceiling. A killed run still reports `timedOut`.
- Drop `_deadlineFor`'s selection term: a silence budget does not care how
  many suites were selected.
- Re-run the self-run; compare timeouts, killed median, and wall clock against
  runs 1-3 and append the row to
  [../self-run-performance.md](../self-run-performance.md).

## Success criteria

- One type owns the budget, the ceiling, and why a run was killed, instead of
  `Duration`s threaded through the engine.
- Self-run timeout rate at or below run 3's 2.41%, without inflating the wall
  clock.
- Regression coverage both ways: a hung test still dies, a slow but noisy test
  is not reported as timed out.
- Result recorded here; ADR 0006 updated in the same branch if the formula
  moves.

## Seams for later

- v1.0 makes the budget per exposure and measured
  ([0021](../../decisions/2026-08-21-beamline-execution.md)): the type must read its
  budget from the unit of work, never from a run-wide field.
- Killing stays the interlock's job
  ([0022](../../decisions/2026-08-21-process-interlock.md)). This item changes when
  to kill, never how.
- Record which limit fired, silence or ceiling. v1.0's beamline rebuild policy
  has to tell a hung exposure from a hung host.

## Result

Pending.
