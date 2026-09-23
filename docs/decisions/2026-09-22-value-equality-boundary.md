---
status: accepted
date: 2026-09-22
decision-makers: []
register:
  spec: 1
  slug: value-equality-boundary
  surfaces:
    - "packages/butcher/lib/src/model/mutation.dart"
    - "packages/butcher/lib/src/model/mutant.dart"
    - "packages/butcher/lib/src/model/mutant_result.dart"
    - "packages/butcher/lib/src/model/test_run.dart"
    - "packages/butcher/lib/src/model/test_suite.dart"
    - "packages/butcher/lib/src/model/test_events.dart"
    - "packages/butcher/lib/src/engine/capped_output.dart"
    - "packages/butcher/lib/src/engine/viability_checker.dart"
    - "packages/butcher/test/model/value_equality_test.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
---
# Value-equality boundary

- Status: accepted

## Context

- The model types were const-constructible with all-final fields but compared
  by identity, so every consumer test asserted field by field and set or map
  membership over them was useless.
- Hand-written equality is the only option available: this is a CLI tool, the
  tree carries no code-generation dependency, and nothing in the workspace
  generates code.

## Decision

- Five model types compare by value, with a matching hash code and a readable
  string form:

| Type | Equality over |
| --- | --- |
| `Mutation` | file path, offset, length, original, replacement, mutator id, description |
| `TestSuite` | path, duration |
| `Mutant` | id and the composed `Mutation` |
| `TestRun` | exit code, timed-out flag, output, error output, duration |
| `MutantResult` | the composed `Mutant`, outcome, the optional `TestRun`, error |

- `TestRun` equality is over the observable outcome only. Its optional parsed
  events are excluded from both the operator and the hash code, because they
  are a derived view of the output string the run already carries.
- Three mechanism classes deliberately get nothing and stay identity-compared:

| Class | Why not |
| --- | --- |
| `TestEvents` | an accumulating parser over a stream, not a value |
| `CappedOutput` | a buffer with mutable state; two buffers holding the same characters are still two buffers |
| `ViabilityChecker` | threads an ever-incrementing stamp into the analyzer overlay, so equality over it would be meaningless and inviting |

- The boundary is gated, not trusted: the value-equality suite asserts that
  the capped output buffer did *not* gain equality, so a later refactor
  cannot quietly hand value semantics to a stateful object.

## Consequences

- Consumers assert on a whole model value, and set and map membership work.
- A wrong hash code or a field left out of equality fails silently in the
  generator, engine, coverage, runner, offset and viability suites, so the
  suite that gates this runs the engine package's whole excluded selection
  rather than the model slice.
- All five types still compile as `const`.

## Rejected

- A code-generation dependency for equality: a build step and a generated
  layer, for five types with fewer than eight fields each.
- Equality for `RunResult`: it holds the full classified list and a source
  map, and comparing it would be a linear scan nothing in the tool performs.
- Equality for `RunAborted`: it is an exception, not a value.
