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

- Exit codes: 0 success, 1 below threshold, 64 usage, 70 aborted run.
- A red test suite aborts the run; a green suite is a precondition.
- `.radignore` (gitignore-style globs, project root) excludes paths from the
  isolated project copy tests run in.

## More

- Documentation: [docs/index.md](docs/index.md)
- Feature staging: [docs/roadmap/index.md](docs/roadmap/index.md)
- Decisions: [docs/decisions/index.md](docs/decisions/index.md)
- `sandbox/`: spike playground, not part of the package
