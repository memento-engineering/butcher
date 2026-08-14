# Spike: shadow-copy mechanics

Goal: prove the MVP isolation model works on Windows before building on it.
Timebox: ~30 min. Throwaway code; only findings are kept.

## Questions to answer

1. Can `dart test` run against a mutated copy of `lib/` without touching the
   working tree?
   - Option A: generated `package_config.json` pointing the package root at a
     temp copy of `lib/`.
   - Option B (fallback, known to work): copy the entire project to a temp dir
     and run tests there.
2. Can a hung `dart test` process tree be killed reliably on Windows?
3. Does test output/exit code behave the same under the chosen option?

## Steps

- Copy `sandbox/lib/` to a temp dir; flip one operator in the copy.
- Try option A; if resolution fails, fall back to option B.
- Run `dart test` via `Platform.resolvedExecutable`; confirm the mutant is
  detected while `sandbox/` stays clean.
- Start a test with an infinite loop; kill the process tree; confirm no
  orphans remain.

## Success criteria

- One option confirmed: mutant killed, working tree untouched.
- Process-tree kill confirmed without orphaned `dart` processes.
- Decision recorded here: chosen option + rationale.

## Result

- Date: 2026-08-14
- Platform: Windows, Dart 3.13.0
- Outcome: success

### Isolation

- Chosen option: A.
- Copied only `lib/` into a temporary package root.
- Added the original `pubspec.yaml` and a generated
  `.dart_tool/package_config.json` to that root.
- Pointed the `sandbox` package entry at the temporary package root.
- Ran the original tests by absolute path from the temporary package root.
- Changed `Calculator.add` from `+` to `-` in the copy.

| Run | Exit code | Output |
|---|---:|---|
| Baseline | 0 | `All tests passed!` |
| Mutant | 1 | Expected `5`, actual `-1` |

- The SHA-256 hash of the working-tree source was unchanged.
- `dart test` does not accept `--packages`; the generated configuration must
  be active at `.dart_tool/package_config.json` in the temporary package root.
- A full project copy is unnecessary.

### Process-tree kill

- Started a test containing a non-terminating loop with no test timeout.
- Captured the Windows process tree, including `dart`, `dartvm`, and the
  frontend server.
- Ran `taskkill /PID <root> /T /F`.
- Confirmed all captured process IDs were gone after termination.

### Decision

Use option A. It isolates mutations with less copying than option B while
preserving normal test output and exit codes. Launch tests with
`Platform.resolvedExecutable` from the temporary package root, and terminate
timeouts with Windows process-tree kill semantics.
