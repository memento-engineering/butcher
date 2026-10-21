---
status: accepted
date: 2026-10-20
decision-makers: ["Nico Spencer"]
register:
  spec: 1
  slug: flutter-test-runner
  surfaces:
    - "packages/butcher/lib/src/engine/flutter_sdk.dart"
    - "packages/butcher/lib/src/engine/flutter_test_runner.dart"
    - "packages/butcher/lib/src/engine/suite_process.dart"
    - "packages/butcher/lib/src/engine/coverage_collector.dart"
    - "packages/butcher/lib/src/engine/pub_get.dart"
  obsoletes: []
  updates:
    - "distribution-and-sdk-resolution"
  obsoleted-by: null
  updated-by:
    - test-entries
  bead: "butcher-5co"
---
# Flutter test runner

- Status: accepted

## Context

- A package depending on the Flutter SDK cannot run `dart test`, so its
  baseline never went green.
- The v1.0 roadmap keeps subprocess `flutter test` as a peer strategy to
  beamlines; a large adopter needed it before beamlines exist.

## Decision

- A package with any `sdk: flutter` dependency, `flutter_test` alone
  included, runs `flutter test --no-pub --reporter json`. No flag or config.
- `flutter test` emits the same JSON protocol, so classification, fail-fast
  and deadlines are unchanged.
- The `flutter` command is the one beside the running `dart`
  (`<flutter>/bin/cache/dart-sdk/bin/dart`), else the one under
  `FLUTTER_ROOT`, else the run aborts. Never `PATH`: this extends 0003's
  "the exact SDK it runs on" to Flutter.
- Dependency resolution goes through `flutter pub get`.
- Coverage comes from `flutter test --coverage-path`: one merged lcov, so
  covered mutants route to the whole suite.
- `--max-heap-mb` is a usage error for a Flutter package: the flag does not
  reach `flutter_tester`.
- Both runners share one suite-process helper; each builds only its command.

## Consequences

- Covered Flutter mutants cost a whole-suite run until per-suite collection
  lands.
- Off-platform goldens are an ordinary red baseline; butcher does not tell
  golden tests apart.
- CI runs the flutter-tagged suites in their own job; elsewhere they skip.

## Rejected

- A flag or `butcher.yaml` key choosing the runner: the manifest already says.
- Running `flutter_tools.snapshot` through `dart` directly: depends on
  Flutter's internal layout.
