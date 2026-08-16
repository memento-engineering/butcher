# radioactive_dart

Mutation testing for Dart. Irradiates `lib/` with mutants and scores which
ones the tests kill.

## Usage

- Run `dart run radioactive_dart:rad` in a project root.
- Prints per-outcome counts, MSI, and covered-code MSI.
- Timed-out mutants are inconclusive: they count as neither killed nor
  survived, and a timeout rate is printed whenever any occur.
- Pass `--coverage` an `lcov.info` (`dart test --coverage-path=lcov.info`) to
  skip mutants no test reaches: they report as `noCoverage` without a run,
  which lowers the MSI but leaves the covered-code MSI intact.
- Writes a Stryker JSON report (`mutation-report.json`); view it with the
  [Stryker report viewer](https://microsoft.github.io/mutation-testing-elements/).

| Flag | Effect |
|---|---|
| `-c, --coverage` | `lcov.info` to route from; unhit lines are not run |
| `-t, --threshold` | Exit 1 when the MSI is below this percentage |
| `--max-timeouts` | Exit 1 when more mutants than this time out |
| `-o, --output` | Report path, relative to the project root |
| `-j, --jobs` | Parallel workers; defaults to half the CPU cores |
| `-v, --verbose` | Also stream structured log events to the console |

- Exit codes: 0 success, 1 gate failed, 64 usage, 70 aborted run.
- A red test suite aborts the run; a green suite is a precondition.
- `.radignore` (gitignore-style globs, project root) excludes paths from the
  isolated project copy tests run in.
- All temp data (containment copies, logs) lives under one rad temp root.
- The default root is `<system temp>/rad/`; `RAD_TEMP` redirects it to an exact
  path.
- A run takes an exclusive `<rad temp root>/.lock`, then clears what earlier
  runs left there. A run that finds the lock held aborts with exit 70 instead
  of touching the other run's state; a crashed run leaves the lock behind.
- Each run writes wide-event CLEF logs to `<rad temp root>/rad.log`,
  replacing the previous run's file. Suite output of every executed mutant is
  kept in `<rad temp root>/runs/`, one log per worker named after its
  containment. The folder remains present; a new run clears only its previous
  contents. Nested engine runs cannot clear or overwrite the active tool run's
  files.

## Windows performance

- Antivirus scanning of containment copies can significantly slow testing.
- Set a dedicated root before running rad:
  `$env:RAD_TEMP = 'D:\temp\rad'`.
- If policy permits, exclude only that dedicated directory from antivirus
  scanning. Do not exclude the whole system temp directory.

## More

- Documentation: [docs/index.md](docs/index.md)
- Feature staging: [docs/roadmap/index.md](docs/roadmap/index.md)
- Decisions: [docs/decisions/index.md](docs/decisions/index.md)
- `sandbox/`: spike playground, not part of the package
