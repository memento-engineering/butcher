# Design: a modern mutation testing tool for Dart

Distilled from the tool survey in [research/](research/README.md) and from mature
tools in other ecosystems ([research/other-ecosystems.md](research/other-ecosystems.md)).

## Core decisions

1. **Written in Dart, parsing with `package:analyzer`.** The official parser
   ships in lockstep with the SDK, so new syntax is supported the day it lands
   in stable. The resolved AST (types, not just syntax) enables mutants that
   are always compilable and type-aware, and avoids many equivalent mutants.
   Precedent: Stryker.NET mutates via Roslyn, the official compiler API.
2. **Distributed via pub.dev** as a dev dependency / `dart pub global activate`.
   Test processes are spawned via `Platform.resolvedExecutable`, so the tool
   always uses the exact SDK it is running on.
3. **The working tree is never modified.** All mutation happens in a shadow
   copy of `lib/` in a temp dir, wired up via a generated
   `package_config.json` (as cargo-mutants does). Interrupting or killing the
   tool at any point leaves the checkout pristine by construction.
4. **Mutant schemata / mutation switching.** All mutants are injected at once
   as branches selected by a `-D` define; compile once, run N times. Validated
   independently by Stryker JS 4.0 (20–70% faster) and Stryker.NET.
   Analyzer-backed rewriting keeps schemata compilable in const contexts;
   mutants in load-time code (top-level/const initializers) fall back to
   per-mutant runs.
5. **Per-test coverage routing.** Collect per-test coverage — or ingest an
   existing `lcov.info`, as Infection ingests PHPUnit coverage — then run only
   the tests covering each mutated line, fastest first, stopping at the first
   kill (pitest's key speed technique). Uncovered mutants are reported
   `NoCoverage`, never executed.
6. **Baseline verification is mandatory.** A green suite (with recorded
   timing) is a precondition for every run; a red baseline aborts with a clear
   message.
7. **TCE equivalent-mutant detection**: compile candidate survivors to kernel
   and hash-compare against the original; discard equivalents.
8. **Deterministic by construction.** Stable mutant IDs (file + node offset +
   operator), seeded ordering, isolated test processes: identical input always
   produces an identical report, so the score is usable as a CI gate.

## Execution pipeline

```
verify baseline green (record timing)
  → shadow-copy lib/ + package_config
  → analyzer: resolved AST → mutants → schemata source
  → per-test coverage (collect or ingest lcov)
  → compile schemata once
  → per mutant: run covering tests, fastest first, first-kill-wins
  → TCE pass over survivors
  → reports + threshold gate (exit code)
```

## Outcome taxonomy (every result is data, never an exception)

`Killed · Survived · NoCoverage · Timeout · Unviable (compile error) ·
RunError · MemoryError · Equivalent (TCE)` — modeled on pitest's seven
categories plus TCE. Timeout = `max(baseline × 3, 10 s floor)`. Policy flags à
la Infection: `--with-timeouts` (count as escaped) and `--max-timeouts`
ceiling.

## Metrics & honesty

- **MSI and covered-code MSI** as separate numbers (Infection) — overall score
  vs. quality of the tests that do exist.
- **Syntax-coverage metric** (novel): % of executable AST nodes the current
  operator set can mutate, plus an explicit list of node kinds encountered but
  unhandled — the report states how much of the language the tool understands.

## Modes & reporting

- **Incremental:** `--diff-base <ref>` at *line* granularity (Infection's
  `--git-diff-lines`), plus a history file for cross-run incremental analysis
  (pitest) and sharding for CI fan-out (cargo-mutants).
- **Reports:** Stryker `mutation-testing-report-schema` JSON first (free
  ecosystem tooling + dashboard), HTML, JUnit, GitHub-annotations logger
  (Infection), and an LLM-optimized Markdown report with per-survivor
  "missing test" hints.
- **Second line of defense:** optionally run `dart analyze` against escaped
  mutants (Infection's PHPStan integration) — a survivor the analyzer would
  flag reveals both a test gap and a lint-config gap.
- **Zero-config default** (cargo-mutants philosophy): `dart run <tool>` in a
  project root must produce a useful report with no setup; config file and
  flags only refine it.

## Non-goals — avoid doing this

Anti-patterns observed in the surveyed tools (details and incidents in
[research/](research/README.md)):

- **No third-party grammars.** A community-maintained grammar trails the
  language and degrades *silently*: unparseable code is skipped while the
  score still looks healthy. If the parser cannot lag the language, this
  entire failure class disappears.
- **No raw-text mutation as the primary engine.** Regex replacement cannot be
  broken by new syntax, but it yields shallow mutant sets on modern constructs
  and produces invalid or accidentally-equivalent mutants. Acceptable only as
  an explicit, clearly-labeled fallback lane for files the analyzer refuses to
  parse.
- **Never mutate files in place.** A crash mid-mutant must not be able to
  leave live mutations in the user's checkout (observed with blight).
- **Never skip baseline verification.** Running against a red suite silently
  inverts kill semantics and produces a confident, wrong report (observed with
  SulthanZahran1's dart-mutant).
- **No uncaught failure modes.** A timeout, OOM, or crashed test process is a
  mutant *result*, never a tool exception (blight died on its own timeout).
  Derive timeouts with a floor so a near-zero baseline cannot collapse them.
- **No PATH-based SDK resolution.** Resolving `dart` from PATH breaks under
  wrapper scripts (`dart.bat` on Flutter/Windows); both Rust tools failed this
  way out of the box.
- **No nondeterminism.** Identical runs that produce different scores
  (observed with Nimblesite's dart_mutant) make the tool unusable as a CI
  gate.
- **No unbounded mutant swarms as the only mode.** Maximizing operator count
  without a coarse/sampled first-pass mode buries signal in noise on large
  codebases.
