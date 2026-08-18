# Changelog

## 0.1.0

- `rad` CLI: irradiates `lib/`, prints per-outcome counts, MSI, and
  covered-code MSI, and writes a Stryker JSON report (`--output`).
- AST mutant generation with `package:analyzer`; mutagens for arithmetic,
  relational, equality, and logical operators plus boolean literals.
- Nullability mutagens: `a ?? b` mutates into always (`b`) and never (`a!`)
  falling back, `?.` access mutates into `!.`, and `null` is injected into
  declared-nullable returns, arguments, assignments, and initializers.
- Containment isolation of the project copy, with gitignore-style
  `.radignore` exclusions that also skip mutant generation; a red background
  reading aborts the run before generation and viability analysis.
- Outcome taxonomy: killed, survived, noCoverage, timeout, unviable, runError.
  Timeouts are inconclusive: they enter neither MSI term, and a timeout rate
  is printed when any occur.
- Gates: `--threshold` on the MSI, `--max-timeouts` on timed-out mutants. A
  run with no scoreable mutants reports no MSI and fails `--threshold`.
- `--coverage` ingests an `lcov.info`: mutants on lines no test hits report as
  `noCoverage` and never run.
- Zero setup: an unresolved project is `pub get`-ed first, a project's own
  `coverage/lcov.info` is picked up without `--coverage`, and otherwise
  coverage is collected in one extra suite run (`--no-collect-coverage`
  falls back to treating all code as covered).
- Mutant runs stop at the first failing test (`dart test --fail-fast`), so the
  project must resolve `package:test` 1.24.6 or newer.
- Static viability check: mutants that fail analysis (e.g. a flipped null
  check breaking type promotion) report as unviable without a test run.
- Promotion-aware guards: equality and logical mutagens skip flips whose
  stranded promotions could never compile, instead of reporting them.
- Parallel classification: `--jobs` workers, each with its own containment.
- Wide-event CLEF logging: one tool log, one run log per containment, each
  mutant's suite output kept as a capped excerpt; `--verbose` renders events to
  the console, ANSI-colored when stdout is a terminal.
- Startup cleanup under an exclusive run lock; a held lock aborts the run,
  and a failed run releases its own lock.
- Keep containments and logs until the next run's startup cleanup.
- Allow `RAD_TEMP` to redirect the containment and log root.
