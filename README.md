# radioactive_dart

Mutation testing for Dart. Irradiates `lib/` with mutants and scores which
ones the tests kill.

## Usage

- Run `dart run radioactive_dart:rad` in a project root.
- Prints per-outcome counts, MSI, and covered-code MSI.
- Writes a Stryker JSON report (`mutation-report.json`); view it with the
  [Stryker report viewer](https://microsoft.github.io/mutation-testing-elements/).

| Flag | Effect |
|---|---|
| `-t, --threshold` | Exit 1 when the MSI is below this percentage |
| `-o, --output` | Report path, relative to the project root |
| `-j, --jobs` | Parallel workers; defaults to half the CPU cores |
| `-v, --verbose` | Also stream structured log events to the console |

- Exit codes: 0 success, 1 below threshold, 64 usage, 70 aborted run.
- A red test suite aborts the run; a green suite is a precondition.
- `.radignore` (gitignore-style globs, project root) excludes paths from the
  isolated project copy tests run in.
- All temp data (containment copies, logs) lives under `<system temp>/rad/`.
- Each run writes wide-event CLEF logs to `<system temp>/rad/rad.log`,
  replacing the previous run's file. Suite output of every executed mutant is
  kept in `<system temp>/rad/runs/`. The folder remains present; a new run
  clears only its contents.

## More

- Documentation: [docs/index.md](docs/index.md)
- Feature staging: [docs/roadmap/index.md](docs/roadmap/index.md)
- Decisions: [docs/decisions/index.md](docs/decisions/index.md)
- `sandbox/`: spike playground, not part of the package
