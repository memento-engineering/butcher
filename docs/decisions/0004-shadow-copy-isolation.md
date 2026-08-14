# 0004: Shadow-copy isolation

- Status: accepted

## Context

- A crash mid-mutant must not corrupt the user's checkout.
- Precedent: cargo-mutants mutates temporary copies of the tree.

## Decision

- Copy the project or workspace into a temp dir and mutate `lib/` there.
- Skip well-known metadata and generated output.
- Support a gitignore-style file for consumer-defined copy exclusions.
- Run tests from the copied package root.
- Mechanics validated by [../plans/spike-shadow-copy.md](../plans/spike-shadow-copy.md).

## Consequences

- Killing the tool at any point leaves the working tree pristine by
  construction.
- No restore logic to get wrong.
- Workspace dependencies and cwd-relative test assets keep their layout.
- Consumers can avoid copying large, project-specific directories.
- Incorrect consumer exclusions fail baseline verification before mutation.

## Rejected

- In-place mutation with backup/restore: restore code is exactly what fails
  during a crash.
- Copying only the mutated package's `lib/`: works for simple packages, but
  workspace resolution and arbitrary test asset paths require more context.
