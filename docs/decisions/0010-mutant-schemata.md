# 0010: Mutant schemata

- Status: accepted, planned v2.0

## Context

- Per-mutant recompilation dominates mutation testing cost in most compiled
  languages. Validated by Stryker JS 4.0 ("mutation switching", 20-70%
  faster) and Stryker.NET.
- It does not dominate here: the containment keeps `dart test`'s incremental
  kernel cache, so a suite run after a real `lib/` edit costs what a warm one
  costs (2.36 s vs 2.34 s, measured in
  [../plans/self-run-performance.md](../plans/self-run-performance.md)).
  What remains per mutant is process startup, which schemata does not remove.

## Decision

- Inject all mutants at once as branches selected by a `-D` define; compile
  once, run N times.
- Analyzer-backed rewriting keeps schemata compilable in const contexts.
- Static-mutant fallback: load-time code (top-level/const initializers) runs
  per-mutant.
- Deferred behind coverage routing
  ([0011](0011-per-test-coverage-routing.md)), which removes far more work per
  mutant than recompilation costs.

## Consequences

- Implemented as an engine rewriting strategy; mutagens and reports untouched
  ([0008](0008-composable-mutator-framework.md)).
- Revisit when a project's per-mutant compile cost is measured to matter, for
  example a large Flutter app.
