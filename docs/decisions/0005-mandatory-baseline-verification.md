# 0005: Mandatory baseline verification

- Status: accepted

## Context

- Running against a red suite silently inverts kill semantics and produces a
  confident, wrong report.
- The baseline run also provides the timing base for timeouts.

## Decision

- A green suite is a precondition for every run; a red baseline aborts with a
  clear message.
- Baseline timing is recorded for timeout derivation ([0006](0006-outcome-taxonomy.md)).

## Rejected

- Skipping or tolerating a failing baseline.
