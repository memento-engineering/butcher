---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: memory-cap
  surfaces:
    - "packages/butcher/lib/src/cli/cli.dart"
    - "packages/butcher/lib/src/engine/dart_test_runner.dart"
    - "packages/butcher/lib/src/engine/outcome_classifier.dart"
    - "packages/butcher/lib/src/model/test_events.dart"
  obsoletes: []
  updates:
    - "outcome-taxonomy"
  obsoleted-by: null
  updated-by: []
  bead: "butcher-0l1"
---
# Memory cap

- Status: accepted

## Context

- A runaway-allocation mutant (an endless `moveNext`) can fill the host's
  memory faster than its deadline fires, killing a CI runner and the run.
- `DART_VM_OPTIONS` does not reach the VM `dart test` runs in; a flag before
  `test` does, and the tests run in that VM's isolates.
- Under a cap the suite reports the test as an `error` event,
  `"Out of Memory"`, and exits 1: today's classifier read that as a kill.
- `MemoryError` was declared by the taxonomy with no producer.

## Decision

- `--max-heap-mb <n>` passes `--old_gen_heap_size=<n>` to every test process:
  baseline, collection and mutants, so calibration runs under the same cap.
  Off by default.
- The option is semantic, not a VM-flag passthrough, so another runner can map
  it to its own mechanism.
- A test whose error is `"Out of Memory"`, or a run whose stderr carries the
  VM's `Exhausted heap space`, classifies as `MemoryError`.
- A non-memory test failure in the same run still classifies as `Killed`.
- `MemoryError` stays outside both MSI terms.

## Consequences

- Peak memory is bounded by roughly `--jobs` times the cap.
- A cap below the suite's own needs turns the baseline red, which aborts with
  the evidence.

## Rejected

- A raw `--test-vm-arg` passthrough: ties the CLI to one VM.
- A default cap now: needs a peak-memory reading of the baseline first.
