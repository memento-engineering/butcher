---
status: accepted
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: shadow-copy-isolation
  surfaces:
    - "lib/src/engine/sandbox.dart"
    - ".butcherignore"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0004"
---
# 0004: Sandbox isolation

- Status: accepted

## Context

- A crash mid-mutant must not corrupt the user's checkout.
- Precedent: cargo-mutants mutates temporary copies of the tree.

## Decision

- Copy the project or workspace into a temp dir (the sandbox) and mutate
  `lib/` there.
- All butcher temp data (sandboxes, logs) lives under one root.
- A non-empty `BUTCHER_TEMP` sets the exact production root.
- The fallback root is `<system temp>/butcher/`.
- The run workspace is locked and cleaned only at the start of the next run
  ([0018](2026-08-15-run-workspace-lifecycle.md)).
- Resolve the root, tool log, and run-log folder once in `ButcherPaths`; pass that
  context through the CLI, engine, sandbox, and logger seams.
- Tests inject an isolated `ButcherPaths` root and never touch production paths.
- Skip well-known metadata and generated output, pruning those directories
  instead of walking them:

| Names | Matched |
| --- | --- |
| `.git`, `.dart_tool` | at any depth; never mutable source |
| `build`, `coverage` | top level only; deeper ones may hold mutable source |
- Support a gitignore-style file for consumer-defined copy exclusions:
  `.butcherignore` at the project root. A directory rule prunes the walk, so a
  negation cannot re-include anything below it, as git documents.
- Run tests from the copied package root.
- Mechanics validated by [../plans/spike-shadow-copy.md](../plans/spike-shadow-copy.md).

## Consequences

- Killing the tool at any point leaves the working tree pristine by
  construction, apart from refreshing project dependencies
  ([0020](2026-08-18-zero-setup-provisioning.md)).
- No restore logic to get wrong.
- Under [0021](2026-08-21-beamline-execution.md) nothing is mutated on disk
  during a run: a mutant is a value, so a sandbox is read-only once its
  beamline is built, apart from what the suite itself writes.
- Workspace dependencies and cwd-relative test assets keep their layout.
- Consumers can avoid copying large, project-specific directories.
- Incorrect consumer exclusions fail the baseline before mutation.

## Rejected

- In-place mutation with backup/restore: restore code is exactly what fails
  during a crash.
- Copying only the mutated package's `lib/`: works for simple packages, but
  workspace resolution and arbitrary test asset paths require more context.
