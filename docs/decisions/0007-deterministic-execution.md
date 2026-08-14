# 0007: Deterministic execution

- Status: accepted

## Context

- Identical runs with different scores make the tool unusable as a CI gate.
- Sharding and history files need stable identifiers.

## Decision

- Stable mutant IDs: file + node offset + operator.
- Seeded ordering; isolated test processes.
- Identical input always produces an identical report.

## Rejected

- Nondeterministic parallel classification.
- Randomized sampling as a roadmap feature: fights score comparability;
  trivial to add later as a flag if ever needed.
