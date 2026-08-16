# 0004: Containment isolation

- Status: accepted

## Context

- A crash mid-mutant must not corrupt the user's checkout.
- Precedent: cargo-mutants mutates temporary copies of the tree.

## Decision

- Copy the project or workspace into a temp dir (the containment) and mutate
  `lib/` there.
- All rad temp data (containments, logs) lives under one root.
- A non-empty `RAD_TEMP` sets the exact production root.
- The fallback root is `<system temp>/rad/`.
- The run workspace is locked and cleaned only at the start of the next run
  ([0018](0018-run-workspace-lifecycle.md)).
- Resolve the root, tool log, and run-log folder once in `RadPaths`; pass that
  context through the CLI, engine, containment, and logger seams.
- Tests inject an isolated `RadPaths` root and never touch production paths.
- Skip well-known metadata and generated output.
- Support a gitignore-style file for consumer-defined copy exclusions:
  `.radignore` at the project root.
- Run tests from the copied package root.
- Mechanics validated by [../plans/spike-shadow-copy.md](../plans/spike-shadow-copy.md).

## Consequences

- Killing the tool at any point leaves the working tree pristine by
  construction.
- No restore logic to get wrong.
- Workspace dependencies and cwd-relative test assets keep their layout.
- Consumers can avoid copying large, project-specific directories.
- Incorrect consumer exclusions fail the background reading before mutation.

## Rejected

- In-place mutation with backup/restore: restore code is exactly what fails
  during a crash.
- Copying only the mutated package's `lib/`: works for simple packages, but
  workspace resolution and arbitrary test asset paths require more context.
