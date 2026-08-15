# 0017: Parallel classification

- Status: accepted

## Context

- Serial whole-suite-per-mutant runs take hours on real projects; the
  self-run took over an hour for 84 mutants.
- Mutant classifications are independent: each needs only its own mutated
  copy of the project.

## Decision

- A worker pool classifies mutants concurrently; pulled forward from v0.1.
- Each worker owns one containment copy ([0004](0004-shadow-copy-isolation.md));
  mutants never share a mutated tree.
- Workers pull from one shared queue; the unit of work stays generic for
  the v1.0 switch to "mutant × covering test".
- `--jobs`/`-j` sets the worker count; default `max(1, cores ~/ 2)` because
  every suite process parallelizes internally already.
- Determinism ([0007](0007-deterministic-execution.md)) is preserved:
  results are stored by mutant index, so completion order never changes the
  report. Progress output follows completion order.
- Suite concurrency is divided among workers
  (`dart test --concurrency = cores ~/ workers`): the total stays near the
  core count instead of oversubscribing multiplicatively.
- The background reading runs once with that same per-suite concurrency, so
  half-lives ([0006](0006-outcome-taxonomy.md)) are calibrated under the
  same conditions the mutant runs see. The first parallel self-run skipped
  this and drowned in load-induced timeouts (53 of 79).

## Rejected

- Sharing one containment with a lock: serializes everything again.
- Defaulting to all cores: nested test-runner parallelism already uses
  them; oversubscription inflates timings against a serial baseline.
- Isolates instead of async workers: the work is process-spawning I/O, not
  Dart-side CPU.
