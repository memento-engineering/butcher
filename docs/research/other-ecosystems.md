# Mutation testing in other ecosystems — ideas worth stealing

Researched 2026-08-14 as input for the
[architecture decisions](../decisions/index.md). Four mature tools,
each the reference implementation of its ecosystem.

## Infection (PHP) — https://infection.github.io

AST-based (nikic/php-parser — notably a *community* parser, but one so dominant
PHP tooling standardized on it). The most operations-mature tool of the four.

**Coverage-driven everything.** Consumes PHPUnit/Codeception coverage reports;
with `--coverage` pointing at existing data it skips the initial test run
entirely. For each mutant it runs *only the tests covering the changed line* —
and with `--only-covering-test-cases`, only the individual covering test cases,
not whole files.

**Two-metric honesty:** reports **MSI** (all mutants) and **covered-code MSI**
(only mutants in covered code) separately. The gap between them quantifies "our
tests are weak" vs. "we don't have tests."

**Line-level git filtering:** `--git-diff-filter` (changed files) and
`--git-diff-lines` (changed *lines* only) with configurable `--git-diff-base` —
makes PR-scoped runs cheap enough for every CI build.

**Timeout policy as flags:** timeouts are their own outcome; `--with-timeouts`
counts them as escaped rather than killed (paranoid mode for slow CI), and
`--max-timeouts` fails the build if too many accumulate.

**Static analysis as a second executioner:** `--static-analysis-tool phpstan`
checks whether escaped mutants would at least be caught by static analysis —
surfacing survivors that are both test gaps *and* analysis-config gaps.

**CI-native loggers:** HTML, JSON summary, plus GitHub- and GitLab-annotation
formats that render survivors as inline PR comments.

**Adopt:** coverage ingestion, per-test-case routing, dual MSI, line-level diff
mode, timeout policy flags, `dart analyze`-as-second-line, annotation loggers.

## PIT / pitest (Java) — https://pitest.org

The long-standing gold standard for speed; mutates **compiled bytecode** rather
than source (no Dart equivalent — kernel isn't stable/documented enough — but
the runner ideas transfer).

**Test targeting + prioritization:** runs a line-coverage analysis of the test
suite first, then for each mutant picks a *targeted set of covering tests
ordered by recorded execution time* — fastest test most likely to kill runs
first, and execution stops at the first kill. This, more than bytecode
mutation, is why pitest scaled to whole codebases when predecessors tested one
class at a time.

**Seven outcome categories:** Killed, Survived, No coverage, Non-viable
(invalid bytecode), Timed out (infinite loops), **Memory error**, **Run error**
— everything is a recorded result, nothing is a crash.

**Incremental analysis:** a history file tracks which mutants were already
tested against which code/test state; unchanged ones aren't re-run on
subsequent executions.

**Adopt:** covering-test prioritization by timing with first-kill short-circuit,
the full outcome taxonomy (incl. memory/run errors), history-file incremental
analysis.

## Stryker (JS + .NET) — https://stryker-mutator.io

**Mutation switching** (Stryker 4.0's signature move): all mutants are
instrumented into the code at once, wrapped in conditionals checking a global
"active mutant" ID, and the runner switches between them across test
executions. One build instead of N — 20–70% faster overall, most dramatic when
a bundler/compile step dominates. This independently validates the schemata
approach SulthanZahran1's Dart tool uses.

**perTest coverage via the same instrumentation:** coverage probes are injected
during the same instrumentation pass, enabling run-only-covering-tests for
another 40–60% — coverage and mutation share one build.

**Known caveat — static mutants:** mutants in code executed at module load time
(top-level initializers, constants) can't be toggled per test run and need
special handling. Directly relevant to Dart top-level/const initializers.

**Stryker.NET specifically** mutates via **Roslyn**, the official .NET compiler
API — the strongest precedent for "use the official parser" (`package:analyzer`
for Dart). The ecosystem also ships the `mutation-testing-report-schema` JSON +
report viewer + a hosted dashboard with per-PR baselines, all reusable for free
by any tool that emits the schema.

**Adopt:** mutation switching (already planned as schemata), coverage probes in
the same instrumented build, static-mutant fallback handling, Stryker JSON as
primary report format (free viewer + dashboard).

## cargo-mutants (Rust) — https://mutants.rs

The best *operational hygiene* of any tool surveyed.

**Scratch-tree isolation:** all mutations happen in temporary copies of the
source tree; the working tree is never modified. (Exactly the countermeasure to
the blight incident, where a crash left live mutations in `calculator.dart`.)

**Zero config by design:** `cargo install cargo-mutants && cargo mutants`
produces useful results on any Cargo project; the tool promises it "won't crash
or hang even when testing mutants that cause hangs."

**"Interesting results" philosophy:** favors coarse, meaningful mutants (e.g.
replace whole function bodies with default values) over exhaustive operator
swarms; explicitly aims to minimize semantically-equivalent noise. A useful
counterweight to maximizing mutant counts — 355 mutants on a 3-file toy project
(SulthanZahran1) is thorough but noisy.

**Practical CI features:** baseline test with timeout capture, `--in-diff` for
changed-code runs, **sharding** to split a run across CI jobs, `unviable` as a
first-class outcome.

**Adopt:** scratch-tree isolation, the no-crash/no-hang guarantee as an explicit
contract, sharding, and an optional "coarse mode" (function-body mutants only)
for fast first passes on large codebases.

## Cross-cutting synthesis

Every mature ecosystem independently converged on the same three pillars, none
of which any current Dart tool has all of:

1. **Compile once** (schemata / mutation switching / bytecode injection) —
   only SulthanZahran1's tool has this in Dart.
2. **Run only covering tests, best-first** — no Dart tool has per-test routing;
   SulthanZahran1 has line-level routing without test selection.
3. **Every failure mode is a result category** — no Dart tool models memory
   errors or run errors; blight treats a timeout as a crash.

The differentiators worth building that *no* surveyed tool in any ecosystem
has: the syntax-coverage honesty metric, and analyzer-resolved (type-aware)
mutant generation via an official parser that cannot lag the language.
