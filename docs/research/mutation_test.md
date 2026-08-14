# mutation_test (domohuhn/mutation-test)

- **pub.dev:** https://pub.dev/packages/mutation_test (v1.8.0)
- **GitHub:** https://github.com/domohuhn/mutation-test
- **License:** BSD-3-Clause
- **Verdict:** ✅ The mature, boring, reliable choice. Worked out of the box.

## Maturity

| Signal | Value |
|---|---|
| Created | September 2021 (~5 years old) |
| Last activity | May 2026 (actively maintained) |
| GitHub stars / forks | 26 / 6 |
| pub.dev | 24 likes, 150 points, **46.9k downloads** |
| Releases | **14 versions** on pub.dev (1.0.0 → 1.8.0, Feb 2026) |
| Open issues | 3 |
| Documentation | Very good: thorough README, full XML schema docs, `-s` flag prints a fully commented example config, API docs on pub.dev |

The only Dart mutation tool with a multi-year track record and a real user base.

## How it works

**Text replacement, not AST.** Mutations are simple literal or regex-based text
replacements (with capture groups) applied to source files. A set of builtin
rules works for Dart out of the box; everything (rules, test commands, expected
exit codes, timeouts, exclusion zones, quality gate) is customizable via XML
documents. Because it operates on text, it is technically language-agnostic —
Dart is just the default target (`lib/**.dart`, test command `dart test`).

For each mutation it rewrites the file, runs the test command as a child
process, and uses the exit code to decide killed vs. survived. Mutations that
produce compile errors still count as "detected" (the test command fails).

Notable extras:
- **Incremental analysis** of only the lines changed between commits (`git diff`).
- Accepts **lcov coverage data** to skip mutating uncovered lines.
- Built-in **quality gate**: configurable rating thresholds; non-zero exit code on failure (CI-friendly).

## Output formats

`--format html|md|xml|junit|xunit|all`, written to `./mutation-test-report/`:

- **HTML** — top-level index + per-source-file annotated pages (undetected mutations as red lines)
- **Markdown** — summary table + per-file diff-style list of undetected mutations
- **XML** (own schema)
- **JUnit XML** and **xunit XML** for CI ingestion

No Stryker-JSON format.

## Local test (Windows 11, Dart 3.13)

Installed as a dev dependency (`dart pub add --dev mutation_test`) in the
`sandbox/` project; ran `dart run mutation_test --format all`.

- **Worked first try, zero configuration, no Windows issues.**
- 30 mutations generated, 20 detected, **10 undetected → 33.3% undetected, rating C**, exit code 255 (quality gate failed — correct, the sample intentionally has weak tests).
- **Runtime: 66 s** for 30 mutations — tests run serially, so it is by far the slowest of the working tools (the Rust tools with parallel execution did more mutants in a fraction of the time).
- Precision was perfect: every undetected mutation was in the deliberately
  under-tested `DiscountService`; the well-tested `Calculator` had zero survivors.
- All five report files were generated correctly (see `sandbox/mutation-test-report/`).

## Internals & stability (deep dive, 2nd session)

Written in **pure Dart**. There is **no parser at all**: 28 builtin rules
(`lib/src/configuration/builtin_rules.dart`) are literal or regex text
replacements — operator swaps (`&&`↔`||`, `==`→`!=`, `+`↔`-`, `*`↔`/`),
compound-assignment simplification (`+=`→`=`), if-condition negation,
function-argument swapping (2–4 args), `break;` removal, list-literal clearing,
number sign flips. Guard regexes exclude string literals (single/triple/double
quoted), comments, `import`/`export` lines, and loop headers (to avoid infinite
loops). Per mutant: rewrite file → run test command → classify by exit code →
restore file. Fully serial.

**Stability consequence of "no parser": it can never be broken by new Dart
syntax.** It doesn't know what syntax is; a Dart 3.99 feature is just more text.
The trade-offs move elsewhere:

- **Low mutation yield on modern constructs.** On a 55-line file exercising
  records, patterns, switch expressions, sealed classes, extension types, digit
  separators, wildcards, and null-aware elements (Dart 3.0–3.8), it generated
  only **10 mutants** — the conservative regexes don't reach inside
  switch-expression arms, record literals, etc. (SulthanZahran1's tool found
  **155** in the same file.)
- **Occasional junk mutants.** Invalid mutants fail compilation, the test
  command exits non-zero, and they're counted as "detected" — mildly inflating
  the score rather than crashing anything.
- **Occasional clever-but-odd mutants.** Its argument-swap rule mutated
  `const Rect(this.width, this.height)`; the survivor was test-equivalent
  (the test used `Rect(3, 4)` and `3*4 == 4*3`).

Ran on the modern-syntax file without a single warning or error (9.6 s,
10 mutants, 1 survivor, rating B).

## Limitations

- Regex-based mutations are less rich than AST-based ones (30 mutants here vs.
  37 for Nimblesite dart_mutant and 200 for SulthanZahran1 dart-mutant on the
  same code) and can occasionally produce semantically equivalent or trivially
  invalid mutants.
- Serial test execution → slow on real-world projects (mitigate with lcov input
  and incremental mode).
- The Markdown/HTML reports embed inline-styled HTML spans; fine in a browser,
  noisy as raw markdown.
