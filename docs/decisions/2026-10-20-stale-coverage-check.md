---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: stale-coverage-check
  surfaces:
    - "packages/butcher/lib/src/cli/cli.dart"
  obsoletes: []
  updates:
    - "zero-setup-provisioning"
  obsoleted-by: null
  updated-by: []
  bead: "butcher-9c5"
---
# Stale coverage check

- Status: accepted

## Context

- A `coverage/lcov.info` left by an earlier run routed mutants with no
  check that it matched the current sources: new lines read as
  `noCoverage`, moved lines were mis-attributed.
- Nothing on the console said which source routed the run.

## Decision

- The order stays given, then found, then collected.
- A found report older than any file under `lib/` or `test/` is stale and
  skipped, beside the existing "records nothing" rule.
- A given report is still honoured as is.
- The console prints one `coverage:` line naming the source: the report and
  its modification time, a skipped stale report, collection, or none.

## Consequences

- Editing any source after `dart test --coverage-path` makes the next run
  collect fresh coverage.
- An mtime check cannot see a report produced from other sources than the
  ones on disk; `--coverage` is the escape hatch either way.

## Rejected

- Using only a `--coverage` report: drops the found rung and makes every run
  pay for collection.
- Comparing the report's `SF:` set against `lib/`: catches added files but
  not edited ones.
