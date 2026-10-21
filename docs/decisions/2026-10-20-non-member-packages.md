---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: non-member-packages
  surfaces:
    - "packages/butcher/lib/src/engine/workspace_closure.dart"
  obsoletes: []
  updates:
    - "sandbox-scope"
  obsoleted-by: null
  updated-by: []
  bead: "butcher-tay"
---
# Non-member packages under package scope

- Status: accepted

## Context

- Package scope copied every file outside a member, including nested,
  independent workspace roots: 201 of 254 MB per sandbox in one adopter's
  repository.
- No kept member can resolve against a package that is not a member, unless
  it names that package by path.

## Decision

- Under `--sandbox-scope=package`, every git-listed directory with its own
  `pubspec.yaml` is skipped unless it is a member, lies inside a kept member,
  or a kept package reaches it through `path:` dependencies, transitively.
- Files outside every package, such as `docs/` or root tooling, are still
  copied.
- Outside a git repository nothing more is skipped.

## Consequences

- A test reading a non-member package's files through `../` goes red under
  package scope, as one reading an unreachable member already does.

## Rejected

- A third `strict` value copying only root files and kept members: the rest
  measured ~9 MB, not worth another mode.
