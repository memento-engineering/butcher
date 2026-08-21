# 0011: Tracer coverage routing

- Status: accepted, staged v0.1-v1.0

## Context

- Running the whole suite per mutant wastes most of the runtime.
- pitest's key speed technique: covering tests only, ordered by recorded
  timing, stop at first kill.
- Infection ingests existing coverage reports to skip the collection step.
- `dart test --coverage` already writes one report per test file, so suite
  granularity needs no extra run; the collector merged that identity away
  ([../plans/self-run-performance.md](../plans/self-run-performance.md)).

## Decision

- v0.1: ingest `lcov.info`; mutants on uncovered lines become `NoCoverage`
  and are never executed.
- v0.1: collect the report when none is supplied
  ([0020](0020-zero-setup-provisioning.md)).
- v0.1: route at suite granularity; one fail-fast run over the covering test
  files, cheapest first, so the first failure ends it.
- v0.1: the half-life stays the background reading's. A suite's own span
  excludes process startup and is not measured under the load the run itself
  creates, so scaling the half-life to the selection times healthy mutants out
  ([../plans/self-run-performance.md](../plans/self-run-performance.md)).
- v0.1: routing may never under-select. An ingested `lcov.info` carries no
  suite identity, and a file no report mentions has no covering suite; both
  fall back to the whole suite.
- v1.0: per-test tracer data; same order and stop rule at test granularity.

## Consequences

- Coverage data model is per-line from the start, extended to
  per-suite -> lines in v0.1 and per-test -> lines in v1.0.
- The scheduler's unit of work changes from "mutant" to "mutant x covering
  test"; the queue stays generic.
- Suite timings come from the collection run, so ordering costs no extra run.
- Routing is only as good as the suite layout: one end-to-end file covering
  everything defeats it, so suite size becomes a performance property of the
  project under test.
