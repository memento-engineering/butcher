# MVP

- Status: complete

Goal: usable on an existing Dart project. Score, metrics, machine-readable
output. Whole-suite-per-mutant.

## Features

- `package:analyzer` AST mutant generation
- Composable mutagen framework; core operators (arithmetic, relational,
  logical, literals)
- Filtered containment isolation; built-in and consumer ignore patterns
- Background reading; half-life floor
- Outcomes: `Killed` / `Survived` / `Timeout` / `Unviable` / `RunError`
- Console summary: MSI + counts per outcome
- Stryker JSON report
- `--threshold` criticality gate via exit code
- SDK via `Platform.resolvedExecutable`; generated-file excludes; stable
  mutant IDs
- Parallel classification via `--jobs` workers (pulled forward from v0.1,
  [ADR 0017](../decisions/2026-08-15-parallel-classification.md))

## Design guidance for later stages

- Ship the seams with trivial defaults: `CoverageProvider` (everything
  covered), `TestSelector` (whole suite), `ReportSink` (console + JSON).
- Outcome enum already contains `NoCoverage` and `Equivalent`.
- Engine owns file rewriting and execution; mutagens only emit `Mutation`
  value objects. The v1.0 schemata switch must touch zero mutagens.
- Test runner behind an interface; v1.0 adds a `flutter test` implementation.
- Mutant IDs derived from file + node offset + operator + replacement:
  stable inputs for v2.0 history files.
