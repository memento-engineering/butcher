# Self-run performance

Where the hours of a `rad` run on this repository go. Measured 2026-08-21
against the 2026-08-18 self-run report and a fresh `dart test` of `main`.

## Baseline

| Fact | Measurement |
|---|---|
| Mutants | 670; 622 executed (21 `CompileError`, 27 `NoCoverage` cost nothing) |
| Cost per executed mutant | the whole suite, every time |
| Whole suite | 143 s wall, 295 s summed over its files |
| Amortized over 8 workers | ~45 s/mutant, so hours for one run |

## One file is the wall clock

| Suite | Own span | Tests |
|---|---|---|
| `test/cli/cli_e2e_test.dart` | 143.0 s | 21 |
| `test/engine/dart_test_runner_test.dart` | 45.1 s | 8 |
| `test/engine/engine_test.dart` | 24.4 s | 13 |
| the other 20 suites | 0.3-11.6 s each | 106 |

Every e2e test is a nested `rad` run: fixture `pub get`, containment,
background reading, coverage collection, per-mutant suites. `dart test`
parallelizes across files but not within one, so the file's span is the
suite's span.

## Recompilation is not the cost

| Run of one small suite | Duration |
|---|---|
| warm | 2.34 s |
| after a real edit to a `lib/` file | 2.36 s |

The containment keeps `dart test`'s incremental kernel cache, so what remains
per mutant is process startup, not compilation
([0010](../decisions/0010-mutant-schemata.md)).

## Routing headroom

`dart test --coverage` writes one report per test file; the collector merged
that identity away. Joining those reports against the report's mutants:

| Model | Serial-equivalent | vs today |
|---|---|---|
| today: whole suite per mutant | 51 h | 100% |
| run all covering suites | 21 h | 42% |
| + fastest first, stop at first kill | ~8 h | 16% |
| same, with no single suite dominating | ~4-6 h | ~10% |

A mutant's line is covered by 2.7 of 23 suites on average, but 70% of mutants
are covered by `cli_e2e_test.dart`, which costs the whole 143 s. Routing and
splitting that file only pay off together
([0011](../decisions/0011-per-test-coverage-routing.md)).

## Result

Both landed: `cli_e2e_test.dart` split into five per-concern files, and each
mutant routed to its covering suites.

| | Before | After |
|---|---|---|
| Whole suite | 143 s | 73 s |
| Self-run | ~6-8 h | 1 h 46 min |
| Per executed mutant, amortized over 8 workers | 45 s | 9 s |
| Mutants | 670 | 702 |

Where the 13.1 h of summed suite time went, over 8 workers:

| Outcome | Mutants | Sum | Median |
|---|---|---|---|
| killed | 564 | 33 868 s | 13.3 s |
| survived | 71 | 3 213 s | 18.4 s |
| timeout | 17 | 10 221 s | 651.1 s |
| noCoverage / unviable | 50 | 0 s | - |

The 17 timeouts cost 22% of the run. That run scaled each mutant's half-life
to its selection, which is wrong in both directions: a selection of heavy
suites earned up to 1003 s, while a selection of cheap ones fell to the 10 s
floor and timed healthy mutants out under load. The half-life is back to the
background reading's (363 s in that run), the only cost measured under the
load the run itself creates, which also bounds those 17 timeouts below what
they cost here.

## What is left

- The `cli_*` suites remain the cost: they are nested `rad` runs, and most
  mutants are covered by one of them.
- `--diff-base` (v1.0) is what makes a per-commit self-run affordable; routing
  makes the full run schedulable, not interactive.
