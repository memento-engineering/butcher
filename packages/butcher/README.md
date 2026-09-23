# butcher

Mutation testing for Dart. butcher rewrites `lib/` into mutants, runs the
tests that cover each one, and scores which mutants the suite kills.

## Where butcher comes from

butcher is a fork of [`radioactive_dart`](https://github.com/ricardoboss/radioactive_dart)
by Ricardo Boss, taken with its full history and continued under the same MIT
licence. The engine, the coverage routing and the sandbox isolation are that
project's work; this fork renames the tool, splits it into a pub workspace and
carries it on. Every member's `LICENSE` keeps the upstream copyright notice.

## Usage

Activate the tool once, then run it from a project root:

```console
$ dart pub global activate butcher
$ butcher
```

A project that depends on butcher can invoke it without activating:

```console
$ dart run butcher:butcher
```

```
Usage: butcher [options] [project root]

-t, --threshold                Exit 1 when the MSI is below this percentage.
-o, --output                   Path of the Stryker JSON report.
                               (defaults to "mutation-report.json")
-c, --coverage                 lcov.info to route from: mutants on lines no test hits are reported as noCoverage without running the suite.
    --max-timeouts             Exit 1 when more mutants than this time out. Timeouts are inconclusive and score as neither killed nor survived.
-j, --jobs                     Parallel workers, each with its own sandbox copy. Defaults to half the CPU cores.
    --[no-]collect-coverage    Collect coverage with an extra instrumented suite run when no report is given or found. Disabling treats all code as covered.
                               (defaults to on)
-v, --verbose                  Also stream structured log events to the console.
-h, --help                     Show this usage.

Environment:
BUTCHER_TEMP  Exact root for sandboxes and logs.
```

## Scores

- Prints per-outcome counts, MSI, and covered-code MSI.
- Timed-out mutants are inconclusive: they count as neither killed nor
  survived, and a timeout rate is printed whenever any occur.
- With no scoreable mutants there is no MSI: scores print as `none` and
  `--threshold` fails.
- Writes a Stryker JSON report (`mutation-report.json`); view it with the
  [Stryker report viewer](https://microsoft.github.io/mutation-testing-elements/).

## Coverage routing

Mutants no test reaches report as `noCoverage` without a run, which lowers the
MSI but leaves the covered-code MSI intact. Coverage comes from, in order:

| Order | Condition | Source |
|---|---|---|
| 1 | `--coverage <path>` given | that `lcov.info` |
| 2 | `coverage/lcov.info` records something | that report |
| 3 | otherwise | butcher collects it in one extra suite run |

- Coverage butcher collects itself also routes: a mutant runs only against the
  test files that cover its line, cheapest first, in one `--fail-fast` run.
  An `lcov.info` names no test files, so rows 1 and 2 run the whole suite per
  mutant.
- `--no-collect-coverage` drops step 3 and treats all code as covered.
- A collection that fails or measures nothing aborts the run instead of
  guessing; rerun with `--no-collect-coverage`.

## Flags

| Flag | Effect | Default |
|---|---|---|
| `-c, --coverage` | `lcov.info` to route from; unhit lines are not run | None |
| `--[no-]collect-coverage` | Collect coverage when no report is given or found | `true` |
| `-t, --threshold` | Exit 1 when the MSI is below this percentage (0-100) | None |
| `--max-timeouts` | Exit 1 when more mutants than this time out | None |
| `-o, --output` | Report path, relative to the project root | `mutation-report.json` |
| `-j, --jobs` | Parallel workers, each with its own sandbox copy | Half the CPU cores |
| `-v, --verbose` | Also stream structured log events to the console | Off |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | The run finished and every gate passed |
| 1 | A gate failed (`--threshold` or `--max-timeouts`) |
| 64 | Usage error |
| 70 | The run aborted: held lock, red baseline, failed `pub get` or coverage collection |

## Baseline and sandbox

- A red test suite aborts the run; a green suite is a precondition. That green
  run is the baseline, and its duration sets the deadline every mutant's suite
  is given.
- The project must resolve `package:test` 1.24.6 or newer; older versions abort
  the run.
- Project dependencies are resolved first: butcher runs `dart pub get`,
  refreshing stale configuration or writing `pubspec.lock` and `.dart_tool/`
  when absent.
- Each worker tests in its own sandbox, a temp-directory copy of the project
  holding what the repository's git listing names. Selecting a pub workspace
  member copies the whole workspace into each sandbox; tests, mutant
  generation, coverage paths and report output stay rooted at the selected
  member.

## Exclusions

Two independent mechanisms. Neither reads `analysis_options.yaml`.

| Mechanism | Decides | Where |
|---|---|---|
| The repository's git listing | What a sandbox copies | The project's own gitignore rules |
| The `exclude` glob list | What butcher mutates | `butcher.yaml` at the project root |

- The copy set is one `git ls-files` at the workspace root: everything git
  tracks, plus everything it reports as untracked and not ignored. Excluding a
  file the suite needs turns the baseline red.
- Copied whether gitignored or not: every `pubspec.lock` beside a package
  manifest, so no sandbox re-resolves its dependencies, and generated sources
  (`.g.dart`, `.freezed.dart`, `.mocks.dart` and the rest).
- Symlinks are recreated as symlinks; one whose target resolves outside the
  workspace is skipped and logged.
- A project outside a git repository falls back to a plain walk excluding only
  `.git`, `.dart_tool` and a top-level `build` or `coverage`, and logs one line
  saying so.
- The bespoke ignore dotfile butcher used to read at the project root is gone,
  and with it its gitignore-style negation. A path that must stay out of the
  sandbox is gitignored instead.
- `exclude` in `butcher.yaml` narrows mutation scope only: an excluded file is
  still copied, still compiled and still runs its tests.

Measured on butcher's own repository, the listing names 179 files (462 KiB)
against the walk's 180 files (473 KiB) — the same tree, because this
repository gitignores nothing but tooling output the walk already skipped. The
reduction scales with what a project gitignores: a generated or vendored tree
the walk copied in full is not copied at all now, once per worker.

## Temp root

All temp data — sandbox copies and logs — lives under one butcher temp root.

| Path | What it holds |
|---|---|
| `<butcher temp root>/` | Default `<system temp>/butcher/`; `BUTCHER_TEMP` redirects it to an exact path |
| `<butcher temp root>/.lock` | The exclusive run lock |
| `<butcher temp root>/butcher.log` | Wide-event CLEF log for the run, replacing the previous run's file |
| `<butcher temp root>/runs/` | One CLEF log per worker, named after its sandbox |
| `<butcher temp root>/sandbox_*/` | The worker sandboxes themselves |

- A run takes the exclusive lock, then clears what earlier runs left there. A
  run that finds the lock held aborts with exit 70 instead of touching the
  other run's state; only a run killed outright leaves the lock behind.
- A 32 KiB head-and-tail excerpt of every executed mutant's suite output is
  kept in `runs/`. The folder remains present; a new run clears only its
  previous contents. Nested engine runs cannot clear or overwrite the active
  tool run's files.
- Sandboxes and logs survive the run that made them, until the next run's
  startup cleanup.

## Windows performance

- Antivirus scanning of sandbox copies can significantly slow testing.
- Set a dedicated root before running butcher:
  `$env:BUTCHER_TEMP = 'D:\temp\butcher'`.
- If policy permits, exclude only that dedicated directory from antivirus
  scanning. Do not exclude the whole system temp directory.

## More

pub.dev renders this file on its own, so every link into the repository's
documentation tree is written as a full
`https://github.com/memento-engineering/butcher` URL rather than a relative
path.

- Documentation: [docs/index.md](https://github.com/memento-engineering/butcher/blob/main/docs/index.md)
- Feature staging: [docs/roadmap/index.md](https://github.com/memento-engineering/butcher/blob/main/docs/roadmap/index.md)
- Design notes: [docs/decisions/views/index.md](https://github.com/memento-engineering/butcher/blob/main/docs/decisions/views/index.md)
