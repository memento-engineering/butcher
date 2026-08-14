# dart_mutator (andrelramos)

- **GitHub:** https://github.com/andrelramos/dart_mutator
- **License:** BSD-style (Stagehand template)
- **Verdict:** ❌ Abandoned non-functional prototype from 2021. Listed only for completeness.

## Maturity

| Signal | Value |
|---|---|
| Created | May 2, 2021 |
| Last push | May 4, 2021 — **2 days of activity, then abandoned 5 years ago** |
| Commits | 8 |
| GitHub stars / forks | 2 / 0 |
| Releases | 0; never published to pub.dev |
| Documentation | None — the README is the untouched Stagehand project template |

## How it works (or doesn't)

Intended as an AST-based mutator in pure Dart. Two operator classes exist
(`InvertBooleanOperationsMutator`, `ArithmeticOperatorMutator`), but the
`bin/dart_mutator.dart` entrypoint merely instantiates them next to a
**hardcoded absolute path from the author's Linux machine**
(`/home/andrebrenda/dev/dart_mutator/bin/example.dart`) and never invokes
anything. There is no test execution, no reporting, no CLI argument handling.

## Output formats

None.

## Local test (Windows 11, Dart 3.13)

Surprisingly, `dart pub global activate --source git
https://github.com/andrelramos/dart_mutator` still resolves and compiles on
Dart 3.13. Running it produces **no output whatsoever** and does nothing, which
matches the skeletal entrypoint. No further investigation warranted.
