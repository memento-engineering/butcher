---
status: accepted
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: shadow-copy-isolation
  surfaces:
    - "packages/butcher/lib/src/engine/sandbox.dart"
    - "packages/butcher/lib/src/engine/file_manifest.dart"
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
- The copy set is the repository's own listing, not a rule butcher invents:
  `git ls-files --cached --others --exclude-standard --deduplicate -z` over
  the workspace root, which names tracked files, untracked-but-not-ignored
  files and index symlinks alike. A project's `.gitignore` is therefore the
  only exclusion dialect, and butcher defines none of its own.
- A short always-include allowlist puts back what the listing drops and the
  sandbox still needs:

| Always included | Why |
| --- | --- |
| `pubspec.lock` beside every `pubspec.yaml` | dropping it re-resolves every sandbox from scratch |
| gitignored generated sources (`.g.dart`, `.freezed.dart`, `.pb*.dart`, `.mocks.dart` and the rest of the generated-suffix list) | a project that gitignores its generated layer would copy none of it and go red on the baseline |

- A root outside a git repository falls back to a hierarchical walk under the
  built-in exclusions alone, and says so in the log: `.git` and `.dart_tool`
  at any depth, `build` and `coverage` at the top level only.
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
- Consumers exclude a directory from the copy the way they already exclude it
  from the repository; there is no second ignore syntax to learn or maintain.
- Incorrect consumer exclusions fail the baseline before mutation.
- What the listing saves scales with what a project gitignores, not with its
  source. Both enumerations, re-run on this repository on 2026-09-22 and named
  in a comment at the top of
  [`packages/butcher/test/engine/file_manifest_test.dart`](../../packages/butcher/test/engine/file_manifest_test.dart),
  are:

| Enumeration | Files | Bytes |
| --- | --- | --- |
| `git ls-files --cached --others --exclude-standard --deduplicate -z` | 218 | 663,910 |
| `find . \( -name .git -o -name .dart_tool -o -path ./build -o -path ./coverage \) -prune -o -type f -print0` | 219 | 675,097 |

  Each is piped through `xargs -0 stat -f%z | awk '{n++; b+=$1} END {print n, b}'`.
  The one file between them is the gitignored `pubspec.lock` (11,187 bytes),
  which the always-include rule puts back, so this repository's sandbox copies
  the same 219 files either way: it gitignores nothing but tooling output,
  which the walk already excluded.

## Rejected

- In-place mutation with backup/restore: restore code is exactly what fails
  during a crash.
- Copying only the mutated package's `lib/`: works for simple packages, but
  workspace resolution and arbitrary test asset paths require more context.
- A per-project ignore file in butcher's own gitignore-style dialect: a second
  implementation of a syntax git already implements, kept correct forever, to
  express what the project's own `.gitignore` already expresses.
