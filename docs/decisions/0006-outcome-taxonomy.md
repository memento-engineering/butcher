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
- Policy flags: `--with-timeouts` (count as escaped), `--max-timeouts`
  ceiling.

## Rejected

- Uncaught timeouts/OOM/crashes.
- Half-life derived from the background reading without a floor: a near-zero
  reading collapses it.
