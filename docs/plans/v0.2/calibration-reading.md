# 2. Calibration reading

- Status: pending
- Decision: [0020](../../decisions/2026-08-18-zero-setup-provisioning.md)
- Needs: [silence-budget.md](silence-budget.md)

Goal: one instrumented pass verifies the suite, records coverage, and times
every suite. A run pays for one full suite instead of two.

## Today

| Pass | Instrumented | Produces |
|---|---|---|
| Baseline | no | green verdict, deadline base |
| Coverage collection | yes | per-line hits, per-suite hits, suite timings |

Both run the whole suite. On this package that is ~73 s spent twice.

## Questions to answer

1. Can `--coverage` turn a green suite red? If yes, the merged pass needs a
   fallback to a separate uninstrumented reading, not an abort.
2. How far does instrumentation inflate suite spans, and does it keep their
   relative order? Routing needs only the order; the budget needs the gaps.
3. The reading runs in `baseline`, and the worker template is cloned before
   it. Where does the coverage output land so no worker inherits it?
4. With a supplied or found `lcov.info` there is nothing to collect. Does the
   reading stay uninstrumented, and does that leave two calibration paths?

## Steps

- Fold `_resolveCoverage` into the reading; instrument only when collection is
  the coverage source.
- Return one calibration record: verdict, coverage provider, suite timings,
  silence budget.
- Keep the abort semantics: a red reading aborts
  ([0005](../../decisions/2026-08-14-mandatory-baseline-verification.md)), coverage
  that records nothing aborts (0020).

## Success criteria

- A bare run performs one full suite pass before generation.
- All three coverage sources still work, covered end to end: `--coverage`, a
  found `coverage/lcov.info`, and collection.
- Self-run wall clock drops by about one suite span.

## Seams for later

- The calibration record is the v1.0 seam: per-test source reports replace
  per-suite ones ([0011](../../decisions/2026-08-14-per-test-coverage-routing.md),
  [0021](../../decisions/2026-08-21-beamline-execution.md)) without the engine
  changing shape.
- Timings stay addressable by suite path; v1.0 keys the same map by test.
- Granularity belongs to the record, not the engine. The engine asks what
  covers a mutant and what it costs, and never learns which.

## Result

Pending.
