# blight (improvingjef)

- **GitHub:** https://github.com/improvingjef/blight
- **License:** MIT
- **Verdict:** ❌ Not usable. Crashed on defaults, hung when reconfigured. Proof-of-concept stage.

## Maturity

| Signal | Value |
|---|---|
| Created | February 22, 2026 |
| Last push | February 22, 2026 — **all activity happened on a single day** |
| Commits | 2 |
| GitHub stars / forks | 0 / 0 |
| Releases | 0; **not published on pub.dev** (README's `dart pub global activate blight` doesn't actually work — must install from git) |
| Documentation | README only, but a decent one: quick start, full `blight.yaml` schema (include/exclude globs, operator selection, test command, timeout multiplier, parallelism) |

The README is more polished than the implementation — it documents behavior the
tool cannot currently deliver.

## How it works (by design)

Pure-Dart tool using the official **`analyzer` package AST** — architecturally
the most "native" approach of all five projects (same parser the Dart SDK uses,
so no grammar-lag issues like tree-sitter). Mutation operators: arithmetic,
relational, logical, unary, literal, statement deletion, return value,
conditional boundary. Flow: parse → apply operators one at a time → run
`dart test` per mutant → report mutation score with surviving mutants listed by
line and type.

## Output formats

Console output only (score percentage + surviving-mutant list). No HTML, JSON,
or JUnit reports exist.

## Local test (Windows 11, Dart 3.13)

Installed from git: `dart pub global activate --source git https://github.com/improvingjef/blight`
(installs and builds fine, Dart 3-compatible).

1. **Run 1 — no config:** "No source files matched the include/exclude
   patterns", despite files sitting in `lib/src/` which the documented default
   pattern (`lib/src/**/*.dart`) should match. Likely a Windows path-separator
   bug in the glob matching.
2. **Run 2 — explicit `blight.yaml`:** found the files, generated 38 mutants
   (14 calculator + 24 discount), killed 3, then **crashed with an unhandled
   `TimeoutException: Test timed out after 2s`**. Root cause: the per-mutant
   timeout is `baseline duration × timeout_multiplier`, and the baseline was
   measured as "0s", collapsing the timeout to ~2 s — which a cold `dart test`
   run on Windows routinely exceeds. The exception is not caught, so the whole
   run dies instead of recording a timeout.
3. **Run 3 — `timeout_multiplier: 100`:** hung at "Running baseline tests ..."
   with near-zero CPU for over 10 minutes on an 8-test suite; had to be killed.
   It also left orphaned `dart` child processes behind after the earlier crash.
4. **Post-mortem discovery — it corrupts your working tree on crash.** The
   run-2 crash happened mid-mutant and blight performed no cleanup: it left
   `calculator.dart` on disk with **two live mutations** (`add` using `-`,
   `subtract` using `+`). This silently broke the baseline for every tool run
   afterwards until manually repaired. The other tools restore files even
   around failures; blight does not. Never point it at an uncommitted tree.

## Assessment

The design (analyzer-based AST mutation in pure Dart) is the right idea and
arguably the best long-term architecture for a Dart mutation tool. But with two
commits, no error handling around process execution, broken default globs on
Windows, and a hang in the happy path, this is an abandoned weekend prototype,
not a tool. Nothing to re-evaluate unless commits resume.
