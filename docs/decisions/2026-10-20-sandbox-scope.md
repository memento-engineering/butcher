---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: sandbox-scope
  surfaces:
    - "packages/butcher/lib/src/engine/workspace_closure.dart"
    - "packages/butcher/lib/src/engine/sandbox.dart"
    - "packages/butcher/lib/src/engine/engine.dart"
    - "packages/butcher/lib/src/cli/cli.dart"
  obsoletes: []
  updates:
    - "shadow-copy-isolation"
  obsoleted-by: null
  updated-by:
    - non-member-packages
  bead: "butcher-5ln"
---
# Sandbox scope

- Status: accepted

## Context

- Selecting one member of a ~40-member workspace copied ~368 MB per sandbox,
  `--jobs + 1` times: setup time, disk and page cache on small CI runners.
- Only the members the selected one can reach take part in its suite.

## Decision

- `--sandbox-scope=package` is opt-in; `workspace`, the default, is unchanged.
- The closure starts at the selected member and the workspace root and
  follows `dependencies`, `dev_dependencies` and `dependency_overrides` that
  name members. Dev dependencies count for every kept member: pub resolves
  them across the whole workspace.
- Members come from `dart pub workspace list`, so globbed `workspace:`
  entries resolve the way pub resolves them.
- The sandbox skips the unreachable members' directories; files outside every
  member are still copied.
- The sandbox's root manifest gets its `workspace:` list rewritten to the kept
  members; the sandbox's existing `pub get` re-resolves.
- A red baseline under package scope says to retry with the default.

## Consequences

- A test that reads an unreachable member's files (a shared fixture through
  `../`) goes red under package scope.
- Making package scope the default needs proof on a large workspace first.

## Rejected

- Package scope as the default now: a missed sibling aborts runs that work
  today.
- Parsing `workspace:` globs ourselves: pub already resolves them.
