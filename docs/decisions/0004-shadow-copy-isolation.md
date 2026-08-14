# 0004: Shadow-copy isolation

- Status: accepted

## Context

- A crash mid-mutant must not corrupt the user's checkout.
- Precedent: cargo-mutants mutates temporary copies of the tree.

## Decision

- Mutate a shadow copy of `lib/` in a temp dir, wired via a generated
  `package_config.json`.
- Mechanics validated by [../plans/spike-shadow-copy.md](../plans/spike-shadow-copy.md).

## Consequences

- Killing the tool at any point leaves the working tree pristine by
  construction.
- No restore logic to get wrong.

## Rejected

- In-place mutation with backup/restore: restore code is exactly what fails
  during a crash.
