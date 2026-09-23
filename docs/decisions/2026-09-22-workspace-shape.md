---
status: accepted
date: 2026-09-22
decision-makers: []
register:
  spec: 1
  slug: workspace-shape
  surfaces:
    - "pubspec.yaml"
    - "packages/butcher/pubspec.yaml"
    - "packages/butcher_process/pubspec.yaml"
    - "packages/butcher_report/pubspec.yaml"
    - ".github/workflows"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
---
# Workspace shape

- Status: accepted

## Context

- Two parts of the tool are useful without the tool: the process-tree kill
  primitives, and the report schema.
- Shipping them inside the engine package makes a consumer of either take the
  analyzer and everything else the engine needs.

## Decision

- One repository, one pub workspace, three published members:

| Member | What it is |
| --- | --- |
| `packages/butcher` | the mutation engine and the `butcher` command-line tool |
| `packages/butcher_process` | process-tree lifetime and kill primitives |
| `packages/butcher_report` | the Stryker mutation-report schema |

- One resolution covers every member. Members depend on each other by plain
  version constraint; there is no path dependency and no overrides file
  anywhere in the tree, so a published consumer resolves exactly what CI
  resolves.
- Members version independently. Each one's release tag is the package name,
  a hyphen, the letter `v` and the version: `butcher-v0.1.0`,
  `butcher_process-v0.1.0`, `butcher_report-v0.1.0`. A repository-wide `v*`
  tag names nothing in a workspace of three versions and is not used.
- A prerelease tag push is a routine release and needs no human: the tag is
  the publish. Promotion to a stable version is a human call.
- The workspace root manifest is `publish_to: none`; it carries the member
  list and the tooling the checks run, nothing that ships.
- Tests run per member, from that member's directory.

## Consequences

- A consumer takes the report schema, or the kill primitives, without the
  engine or the analyzer.
- A breaking change in one member is a version bump in that member and a
  constraint bump in the ones that depend on it, in one commit.
- Every workflow that publishes has to be told which member it is publishing,
  because the tag says so and nothing else does.

## Rejected

- One package with optional parts: Dart has no optional dependency, so the
  engine's dependencies would be every consumer's dependencies.
- Separate repositories per member: three sets of CI, three histories, and a
  cross-repository change for every shared refactor.
- A repository-level `v<version>` tag: ambiguous the moment two members carry
  different versions, which is on the first patch release.
