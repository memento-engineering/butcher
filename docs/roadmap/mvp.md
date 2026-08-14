# MVP

Goal: usable on an existing Dart project. Score, metrics, machine-readable
output. Serial, whole-suite-per-mutant.

## Features

- `package:analyzer` AST mutant generation
- Composable mutator framework; core operators (arithmetic, relational,
  logical, literals)
- Filtered shadow-copy isolation; built-in and consumer ignore patterns
- Baseline verification; timeout floor
- Outcomes: `Killed` / `Survived` / `Timeout` / `RunError`
- Console summary: MSI + counts per outcome
- Stryker JSON report
- `--threshold` quality gate via exit code
- SDK via `Platform.resolvedExecutable`; generated-file excludes; stable
  mutant IDs

## Design guidance for later stages

- Ship the seams with trivial defaults: `CoverageProvider` (everything
  covered), `TestSelector` (whole suite), `ReportSink` (console + JSON).
- Outcome enum already contains `NoCoverage` and `Equivalent`.
- Engine owns file rewriting and execution; mutators only emit `Mutation`
  value objects. The v1.0 schemata switch must touch zero mutators.
- Test runner behind an interface; v0.1 adds a `flutter test` implementation.
- Mutant IDs derived from file + node offset + operator: stable inputs for
  v2.0 history files.
