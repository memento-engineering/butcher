# Spike: mutator framework shape

Goal: validate the mutator API reads as intended before writing many
operators. Timebox: ~1 h. Throwaway code; only findings are kept.

Historical record; predates [0014](../decisions/0014-naming-and-vocabulary.md):
"mutator" is now "mutagen".

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

## Findings (2026-08-14)

Verdict: the shape holds; all success criteria met. Friction points below
folded into ADRs
[0002](../decisions/0002-parse-with-official-analyzer.md),
[0007](../decisions/0007-deterministic-execution.md) and
[0008](../decisions/0008-composable-mutator-framework.md).

### Answers

| # | Question | Answer |
|---|---|---|
| 1 | ~15 declarative lines? | Yes: pure-data swap 16 lines (9 declarative), guarded swap 29 |
| 2 | One visitor walk enough? | Yes: `RecursiveAstVisitor` dispatching per node kind to the registry |
| 3 | `Mutation` sufficient? | Yes: span replacement alone produced compiling mutants |

### API sketch that worked

- `Mutation` — immutable: file path, offset, length, original, replacement,
  operator id, description.
- `Mutator` — marker interface with `id`.
- `BinaryExpressionMutator` — base class: `swaps` table
  (`'+' → ['-']`) + overridable `guard(node)`; turns nodes into `Mutation`s.
- `MutatorRegistry` — active set; visitor filters by node-kind base type.
- `MutationVisitor extends RecursiveAstVisitor` — the single walk;
  mutators never traverse.

### Evidence

- 32 mutants over `sandbox/lib/`; two enumeration runs byte-identical.
- Guard read resolved types inside switch-expression `when` guards and
  extension types; correctly vetoed a custom `operator >` on a probe class.
- 34/35 mutants compiled (`dart analyze` on a temp copy).

### Friction points

- `AnalysisContextCollection` throws on non-normalized paths;
  normalize with `package:path` first.
- Visitor emits parent-before-child order (`3.14159 * r * r`: outer `*`
  first). Deterministic, but the engine must sort by (file, offset)
  before assigning mutant ids.
- The one broken mutant: unguarded `+ → -` on string concatenation.
  Even pure-data swaps need a numeric guard by default on the base
  class; widening stays an override.
- Resolution dominates runtime; create the context collection once and
  reuse it across files.
