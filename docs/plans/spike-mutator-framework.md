# Spike: mutator framework shape

Goal: validate the mutator API reads as intended before writing many
operators. Timebox: ~1 h. Throwaway code; only findings are kept.

## Questions to answer

1. Does a typical mutator fit in ~15 declarative lines?
2. Is one analyzer visitor walk enough to dispatch to all registered mutators?
3. Is the `Mutation` value object (span, replacement, operator id,
   description) sufficient for the engine to rewrite files?

## Steps

- Parse `sandbox/lib/` with `package:analyzer` (resolved AST).
- Build minimal pieces: `Mutation` value object, `Mutator` interface,
  registry, single dispatching visitor.
- Implement two mutators:
  - data-driven operator swap (`'+' → ['-']` on a shared base class)
  - one with a guard predicate (e.g. relational swap only on numeric operands)
- Apply one mutation via span replacement; confirm the result compiles.

## Success criteria

- Both mutators are small, declarative, and readable.
- Mutant list for `sandbox/lib/` is deterministic across runs.
- Type information (resolved AST) is accessible inside a guard predicate.
- Findings recorded here: API sketch that worked + friction points.
