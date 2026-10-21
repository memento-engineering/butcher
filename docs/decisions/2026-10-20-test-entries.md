---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: test-entries
  surfaces:
    - "packages/butcher/lib/src/cli/cli.dart"
    - "packages/butcher/lib/src/config/butcher_config.dart"
    - "packages/butcher/lib/src/engine/named_tests_runner.dart"
  obsoletes: []
  updates:
    - "two-mechanism-configuration"
    - "flutter-test-runner"
  obsoleted-by: null
  updated-by: []
  bead: "butcher-gfi"
---
# Test entries

- Status: accepted

## Context

- Large adopters bundle every `*_test.dart` into one generated entry, so VM
  startup and binding setup are paid once.
- butcher let the runner discover every `*_test.dart`, so each mutant paid
  one startup per file: `flutter_tester` per file under Flutter.
- Per-file coverage collection would have restored routing for Flutter, but
  costs a `flutter test` startup per file and routes nothing for a bundle.

## Decision

- `butcher.yaml` gains a second key, `tests`: a list of project-relative test
  files run in place of the discovered suite.
- `--test <path>`, repeatable, names them for one run and overrides `tests`.
- Every whole-suite run uses them: the baseline, coverage collection, and
  each mutant that routing leaves unnarrowed.
- An entry must be an existing `.dart` file inside the package, else 64.
- One runner decorator substitutes the entries for an empty selection; the
  Dart and Flutter runners are unchanged.
- Per-file coverage collection for Flutter is dropped: a Flutter package
  routes per entry, or to its whole suite.

## Consequences

- A bundled package pays one startup per mutant run.
- Under Dart, routing still narrows among several entries.

## Rejected

- `--test-path`, a single entry: a package may bundle into several.
- Per-file `flutter test --coverage` runs: thousands of startups to route a
  suite that runs as one bundle anyway.
