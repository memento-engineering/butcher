---
status: accepted
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: mandatory-baseline-verification
  surfaces:
    - "packages/butcher/lib/src/engine/engine.dart"
    - "packages/butcher/lib/src/engine/run_aborted.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0005"
---
# 0005: Mandatory baseline verification

- Status: accepted

## Context

- Running against a red suite silently inverts kill semantics and produces a
  confident, wrong report.
- The baseline run also provides the timing base for deadlines.

## Decision

- A green suite is a precondition for every run; a red baseline
  aborts with a clear message.
- Baseline timing is recorded for deadline derivation ([0006](2026-08-14-outcome-taxonomy.md)).

## Rejected

- Skipping or tolerating a failing baseline.
