# 0005: Mandatory background reading

- Status: accepted

## Context

- Running against a red suite silently inverts kill semantics and produces a
  confident, wrong report.
- The background reading (baseline run) also provides the timing base for
  half-lives.

## Decision

- A green suite is a precondition for every run; a red background reading
  aborts with a clear message.
- Background timing is recorded for half-life derivation ([0006](0006-outcome-taxonomy.md)).

## Rejected

- Skipping or tolerating a failing background reading.
