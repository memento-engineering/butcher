# 0013: Score and honesty metrics

- Status: accepted

## Context

- A single score hides whether tests are weak or missing.
- A tool that falls behind the language must say so instead of shipping a
  silently inflated score.

## Decision

- Report MSI and covered-code MSI as separate numbers (Infection).
- Syntax-coverage metric: % of executable AST nodes the operator set can
  mutate, plus a list of node kinds encountered but unhandled.
- v0.1 ships the node-kind census as a warning; v1.0 puts the full metric in
  reports.

## Consequences

- The census is stored in the run result, not just logged.
