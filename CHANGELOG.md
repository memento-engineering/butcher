# Changelog

## Unreleased

- `rad` CLI: irradiates `lib/`, prints per-outcome counts, MSI, and
  covered-code MSI, and writes a Stryker JSON report (`--output`).
- AST mutant generation with `package:analyzer`; mutagens for arithmetic,
  relational, equality, and logical operators plus boolean literals.
- Nullability mutagens: `a ?? b` mutates into always (`b`) and never (`a!`)
  falling back, `?.` access mutates into `!.`, and `null` is injected into
  declared-nullable returns, arguments, assignments, and initializers.
- Containment isolation of the project copy, with `.radignore` exclusions;
  a red background reading aborts the run.
- Outcome taxonomy: killed, survived, noCoverage, timeout, unviable, runError.
  Timeouts are inconclusive: they enter neither MSI term, and a timeout rate
  is printed when any occur.
- Gates: `--threshold` on the MSI, `--max-timeouts` on timed-out mutants.
- `--coverage` ingests an `lcov.info`: mutants on lines no test hits report as
  `noCoverage` and never run.
- Mutant runs stop at the first failing test (`dart test --fail-fast`).
- Static viability check: mutants that fail analysis (e.g. a flipped null
  check breaking type promotion) report as unviable without a test run.
- Promotion-aware guards: equality and logical mutagens skip flips whose
  stranded promotions could never compile, instead of reporting them.
- Parallel classification: `--jobs` workers, each with its own containment.
- Wide-event CLEF logging: one tool log, one run log per containment,
  `--verbose` renders events to the console.
- Startup cleanup under an exclusive run lock; a held lock aborts the run.
- Keep containments and logs until the next run's startup cleanup.
