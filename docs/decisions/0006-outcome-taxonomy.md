# 0006: Outcome taxonomy

- Status: accepted

## Context

- Mature tools (pitest) model every failure mode as a result category.
- A tool exception mid-run loses all completed work.

## Decision

- Every mutant result is data, never an exception:
  `Killed · Survived · NoCoverage · Timeout · Unviable · RunError ·
  MemoryError · Equivalent`.
- The full enum exists from the MVP, even for outcomes produced only by later
  stages.
- Half-life (per-mutant timeout) = `max(background reading × 3, 10 s floor)`.
- `Killed`, `Survived`, and `Timeout` remain separate peer outcomes in results.
- Timeouts are inconclusive. They count as neither killed nor survived.
- `--max-timeouts` fails a run when its timeout ceiling is exceeded.
- A timed-out suite is killed with its children: `taskkill /T` on Windows,
  elsewhere a `ps` snapshot taken before the kill. Best effort by design:
  `setsid` is absent from minimal images and Dart cannot spawn a process
  group, so a process spawned after the snapshot survives.

## Rejected

- Uncaught timeouts/OOM/crashes.
- Folding timeouts into killed or survived results.
- Half-life derived from the background reading without a floor: a near-zero
  reading collapses it.
