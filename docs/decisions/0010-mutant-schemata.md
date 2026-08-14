# 0010: Mutant schemata

- Status: accepted, planned v1.0

## Context

- Per-mutant recompilation dominates mutation testing cost.
- Validated independently by Stryker JS 4.0 ("mutation switching", 20–70%
  faster) and Stryker.NET.

## Decision

- Inject all mutants at once as branches selected by a `-D` define; compile
  once, run N times.
- Analyzer-backed rewriting keeps schemata compilable in const contexts.
- Static-mutant fallback: load-time code (top-level/const initializers) runs
  per-mutant.

## Consequences

- Implemented as an engine rewriting strategy; mutators and reports untouched
  ([0008](0008-composable-mutator-framework.md)).
