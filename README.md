# butcher

Mutation testing for Dart: rewrite the source into mutants, run the tests that
cover each one, and score which mutants the suite kills.

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces)
with three published members, so a consumer can take a part without taking the
whole tool:

| Member | What it is |
| --- | --- |
| [`packages/butcher`](packages/butcher) | The mutation engine and the `butcher` command-line tool. |
| [`packages/butcher_process`](packages/butcher_process) | Process-tree lifetime and kill primitives. |
| [`packages/butcher_report`](packages/butcher_report) | The Stryker mutation-report schema. |

**Start at [`packages/butcher/README.md`](packages/butcher/README.md)** for
installation and usage; this file only describes the repository's shape.

## Working in the workspace

One resolution covers every member, and the members depend on each other by
plain version constraint — there is no path dependency and no overrides file
anywhere in the tree.

```console
$ dart pub get                        # resolves all three members
$ dart analyze                        # analyzes all three members
$ dart run tool/check_workflows.dart  # asserts the CI workflow's shape
```

Tests run per member, from that member's directory:

```console
$ cd packages/butcher && dart test
$ cd packages/butcher && dart test -x slow   # skips the real-subprocess suites
```

The suites that spawn real subprocesses carry a `slow` tag in their own source;
[`packages/butcher/dart_test.yaml`](packages/butcher/dart_test.yaml) declares
the tag and records what each one costs.

## Background

butcher derives from the MIT-licensed `radioactive_dart` package by Ricardo
Boss, forked with its full history. Every member's
[LICENSE](packages/butcher/LICENSE) keeps the upstream copyright notice.

Design notes and prior-art surveys live under [`docs/`](docs/index.md).
