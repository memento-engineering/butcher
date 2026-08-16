# 0019: Static viability filtering

- Status: accepted

## Context

- Flipping `==`/`!=` or `&&`/`||` around a null check can break flow-based
  type promotion in code the mutation never touched; such mutants do not
  compile.
- Dogfooding v0.1: 26 of 174 mutants were unviable and burned ~34 minutes of
  test time (avg 79 s each) before failing to load.
- Syntactic gates cannot decide viability: whether a flip compiles depends
  on promotion uses elsewhere in the function. A "never mutate null checks"
  gate would also have dropped 6 viable mutants, one a genuine survivor.

## Decision

- Mutants must compile; the engine verifies this statically instead of
  trusting mutagen guards.
- After generation, each covered mutant's file is re-resolved through an
  in-memory analyzer overlay; error diagnostics classify the mutant
  `unviable` with no test run.
- Only `COMPILE_TIME_ERROR` and `SYNTACTIC_ERROR` diagnostics deny
  viability; warnings and lints escalated to error severity do not.
- Only the mutated file is re-analyzed: mutagens rewrite expressions inside
  bodies, which cannot change a file's API. Declaration-changing mutagens
  must widen the check first.

## Consequences

- Mutagen guards stay permissive: viable null-check flips keep running while
  hopeless ones die in milliseconds.
- Schemata ([0010](0010-mutant-schemata.md)) requires every injected mutant
  to compile; this filter is its prerequisite.
- The TCE pass ([0012](0012-tce-equivalent-detection.md)) becomes a peer
  filter stage on the same infrastructure.

## Rejected

- Gating null comparisons in mutagens: drops viable mutants and stays
  unsound (`is` checks, definite assignment).
- Reimplementing flow analysis at generation time: fragile duplication of
  the compiler.
