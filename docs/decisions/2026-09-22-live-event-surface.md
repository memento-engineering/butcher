---
status: accepted
date: 2026-09-22
decision-makers: []
register:
  spec: 1
  slug: live-event-surface
  surfaces:
    - "packages/butcher/lib/src/engine/run_events.dart"
    - "packages/butcher/lib/src/engine/engine.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
---
# Live event surface

- Status: accepted

## Context

- A mutation run is long. Until it ended, the only thing an embedder could
  show was that it had not ended.
- The end-of-run report is the record of what happened; it is not a progress
  view, and making it one would mean writing it incrementally.

## Decision

- The engine publishes a typed event stream beside the end-of-run
  `RunResult`. The stream is additive: the report keeps exactly the shape and
  the contents it already had, and an embedder that ignores the stream sees
  no change.
- The stream is a sealed hierarchy of three events: one `RunStarted` carrying
  the mutant count and the two timings the report will also show, one
  `MutantClassified` per mutant carrying the same `MutantResult` the report
  will carry, and one `RunCompleted`.
- Event order is NON-DETERMINISTIC by construction: the workers classify in
  parallel ([0017](2026-08-15-parallel-classification.md)) and publish as
  they finish. The `RunResult` keeps the slot-indexed order and stays the
  stable, ordered view of the run.
- The run closes the stream in a `finally`, so an aborted run closes it
  instead of leaving a listener hanging. An engine instance is therefore
  single-use for its stream.
- Delivery is asynchronous: a listener that throws does not throw inside the
  engine. Its exception surfaces in the zone where it subscribed, and the run
  neither swallows nor observes it.

## Consequences

- An embedder renders progress without parsing the log, and renders the same
  numbers the report will show.
- A consumer that wants results in a stable order reads the `RunResult`, not
  the stream; sorting the stream would only re-derive what the result already
  holds.
- Subscribing has to happen before `run()` is called.

## Rejected

- Writing the report incrementally so a reader can poll it: it makes the
  record a progress view and every partial read a half-truth.
- An ordered stream: the workers are parallel, so ordering means buffering
  until the missing slot resolves, which is the end-of-run result with extra
  steps.
- Progress on the wide-event log ([0016](2026-08-15-wide-event-logging.md)):
  that log is a diagnostic record for an operator, not a typed API for an
  embedder.
