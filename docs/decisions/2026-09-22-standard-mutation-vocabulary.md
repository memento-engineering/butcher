---
status: accepted
date: 2026-09-22
decision-makers: []
register:
  spec: 1
  slug: standard-mutation-vocabulary
  surfaces:
    - "packages/butcher/lib/src/mutators/mutator.dart"
    - "packages/butcher/lib/src/mutators/mutator_registry.dart"
    - "packages/butcher/lib/src/engine/sandbox.dart"
    - "packages/butcher/lib/src/butcher_paths.dart"
    - "packages/butcher/lib/src/log/butcher_logger.dart"
    - "packages/butcher/lib/src/engine/run_result.dart"
  obsoletes:
    - "naming-and-vocabulary"
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
---
# Standard mutation-testing vocabulary

- Status: accepted

## Context

- The tool inherited a themed vocabulary: one metaphor supplying a name for
  every concept, across the source, the CLI text, the log properties and the
  docs.
- Mutation testing already has settled terms that every reader of such a tool
  shares, and a themed name means a reader translates before understanding.
- The retired terms are not spelled out here. A docs check greps the tree for
  them, so naming them would re-introduce exactly what the sweep removed; the
  sweep's own record carries them.

## Decision

- butcher uses the field's standard terms only. No thematic name survives in
  any identifier, file path, CLI string, log property or document.
- One term per concept, everywhere:

| Concept | Term |
| --- | --- |
| a single change applied to the source | mutation |
| the program carrying one such change | mutant |
| the class producing mutations of one kind | mutator |
| the temp-dir copy a run mutates in | sandbox |
| the green reference run the deadline is derived from | baseline |
| the per-mutant timeout budget | deadline |
| a mutant a test detected | killed |
| a mutant no test detected | survived |
| a mutant no test covers | no coverage |
| a mutant whose run outlasted its deadline | timeout |
| a mutant no test could ever detect | equivalent |
| the proportion of detected mutants | mutation score |

- The tool's own nouns take its name: the executable, the logger, the path
  resolver, the temp root and the environment override are all spelled
  `butcher`.
- Three classes of name are exempt, because they are contracts with something
  outside this tree:

| Exempt | Why |
| --- | --- |
| the mutator id strings (`arithmetic`, `bool-literal`, `null-coalescing` and their siblings) | embedded in every mutant id and in every published report; only the Dart field name changed |
| the report schema's status spellings ([0009](2026-08-14-stryker-json-primary-report.md)) | another project's wire contract |
| the `Outcome` enum values | already standard terms, never part of the theme |

## Consequences

- A reader who has used any other mutation-testing tool reads butcher's
  output without a glossary.
- The rename reached string literals asserted verbatim in the suites, not
  only identifiers, so the sweep was a code change gated by tests rather than
  a search and replace.
- The docs check greps for the retired terms, so the vocabulary cannot drift
  back in a later change.

## Rejected

- Keeping the theme and documenting a glossary: the translation cost is paid
  by every reader, forever, to save one rename.
- Renaming the exempt names for consistency: it would break published mutant
  ids and every consumer matching the report's status strings.
