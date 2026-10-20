---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: scoped-runs
  surfaces:
    - "packages/butcher/lib/src/cli/cli.dart"
    - "packages/butcher/lib/src/config/diff_scope.dart"
    - "packages/butcher/lib/src/engine/engine.dart"
    - "packages/butcher/lib/src/report/stryker_json_sink.dart"
  obsoletes: []
  updates:
    - "two-mechanism-configuration"
  obsoleted-by: null
  updated-by: []
  bead: "butcher-hif"
---
# Scoped runs

- Status: accepted

## Context

- A full-package run takes hours on a large package; an agent checking its
  own change, or a pull-request lane, needs minutes.
- The v1.0 roadmap plans `--diff-base` at line granularity; file granularity
  already answers the agent case.

## Decision

- Two CLI flags narrow the `lib/` walk for one run; `butcher.yaml` stays
  exclude-only and `exclude` still applies inside the scope.

| Flag | Scope |
|---|---|
| `--files <path>` | the named `lib/` `.dart` files, relative to the project root |
| `--diff-base <ref>` | `lib/` files changed in the working tree against `<ref>`, plus untracked ones |

- The flags are mutually exclusive; a path outside `lib/`, a missing file or
  an unresolvable ref is a usage error (64).
- `--diff-base` compares the working tree, not `<ref>...HEAD`: an agent's
  edits are usually uncommitted. Deleted files drop out.
- The baseline and coverage collection still run the whole suite: routing
  data comes from that collection, so it cannot narrow the baseline first.
- A scoped report records its sorted scope under the document's `config`, so
  a dashboard never reads it as the package score.

## Consequences

- A scoped run costs two suite runs plus the scope's mutants.
- Line granularity can later narrow `--diff-base` without a new flag.

## Rejected

- An `include` key in `butcher.yaml`: scope is per run, not per project.
- `<ref>...HEAD`: misses uncommitted work.
- Letting `--files` and `--diff-base` combine: union or intersection would
  both surprise someone.
