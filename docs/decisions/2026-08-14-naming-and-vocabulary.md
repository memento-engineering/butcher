---
status: retired
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: naming-and-vocabulary
  surfaces:
    - "pubspec.yaml"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0014"
---
# 0014: Naming and vocabulary

- Status: retired

## Retired

This entry chose a themed vocabulary for the tool and fixed one term per
concept across the docs, the CLI and the reports. That choice is gone. The
tool now uses the field's own standard terms, which every reader of a
mutation-testing tool already shares: mutant, mutation, mutation score,
killed, survived, timeout, no coverage, equivalent and mutator. The metaphor
this entry argued for is retired with it, and nothing in its argument
survives translation into the standard terms, so the argument is not
restated here.

The unthemed choices the entry recorded were never part of the theme and
still hold: the `Outcome` enum values, the Stryker JSON field names
([0009](2026-08-14-stryker-json-primary-report.md)), "schemata"
([0010](2026-08-14-mutant-schemata.md)) and "mutation score" / MSI, and the
CLI flag names.

The file stays in the register, and the index keeps listing it, so every
inbound link to this entry keeps resolving.
