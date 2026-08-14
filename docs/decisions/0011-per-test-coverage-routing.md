# 0011: Tracer coverage routing

- Status: accepted, planned v1.0 (lcov ingestion: v0.1)

## Context

- Running the whole suite per mutant wastes most of the runtime.
- pitest's key speed technique: covering tests only, ordered by recorded
  timing, stop at first kill.
- Infection ingests existing coverage reports to skip the collection step.

## Decision

- v0.1: ingest `lcov.info`; mutants on uncovered lines become `NoCoverage`
  and are never executed.
- v1.0: per-test tracer data; run only covering tests, fastest first,
  first-kill-wins.

## Consequences

- Coverage data model is per-line from the start, extended to
  per-test → lines in v1.0.
- The scheduler's unit of work changes from "mutant" to
  "mutant × covering test"; the queue stays generic.
