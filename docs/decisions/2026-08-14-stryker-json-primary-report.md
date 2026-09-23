---
status: accepted
date: 2026-08-14
decision-makers: []
register:
  spec: 1
  slug: stryker-json-primary-report
  surfaces:
    - "packages/butcher/lib/src/report/stryker_json_sink.dart"
    - "packages/butcher_report/lib/butcher_report.dart"
    - "packages/butcher_report/lib/src/mutant_status.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0009"
---
# 0009: Stryker JSON as primary report

- Status: accepted

## Context

- A custom format would need its own tooling forever.
- The Stryker `mutation-testing-report-schema` has a free report viewer,
  dashboard, and ecosystem.

## Decision

- Emit Stryker JSON from the MVP on.
- Later formats (HTML, LLM Markdown) are additive `ReportSink`
  implementations.
- The schema is a package of its own, `butcher_report`: the report types,
  their parse and their serialisation, with no I/O and no dependency on the
  engine. A consumer that reads or writes the report depends on the schema
  alone; `butcher` depends on it to write one.
- The names on the wire are the schema's, not butcher's. `MutantStatus`
  spells its eight values `Killed`, `Survived`, `NoCoverage`,
  `CompileError`, `RuntimeError`, `Timeout`, `Ignored` and `Pending`, and
  those spellings are deliberately left unthemed and unrenamed while the
  vocabulary around them was rewritten: they are another project's interop
  contract, and a reader or dashboard matches them literally.

## Consequences

- Browsable HTML via the Stryker viewer without writing any HTML.
- Machine-readable output from day one.
- A report consumer takes one small package and none of the engine's
  dependencies; the schema versions on its own cadence.
- `CompileError` and `RuntimeError` do not line up one-to-one with the
  outcome taxonomy ([0006](2026-08-14-outcome-taxonomy.md)); the mapping is
  the sink's job and the wire names stay as the schema defines them.

## Rejected

- A throwaway custom JSON schema for the MVP.
- JUnit XML output (dropped from the roadmap).
