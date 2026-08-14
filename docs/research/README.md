# Dart Mutation Testing — Ecosystem Research

Research date: **2026-08-14** · Machine: Windows 11 x64, Dart 3.13.0 (via Flutter 3.47.0)

Five projects were found that attempt mutation testing for Dart/Flutter. Each was
evaluated for maturity (age, stars, releases, documentation) and — where feasible —
run locally against a purpose-built sample project (`sandbox/`) containing a
well-tested `Calculator` class and a deliberately under-tested `DiscountService`
class, so both killed and surviving mutants were expected.

## Verdict at a glance

| Project | Report | Approach | Age | Stars | Releases | Docs | Worked locally? |
|---|---|---|---|---|---|---|---|
| [mutation_test](https://pub.dev/packages/mutation_test) | [mutation_test.md](mutation_test.md) | Text/regex replacement | Sep 2021 (~5 yrs) | 26 GH / 24 pub likes | 14 (pub) | Very good | ✅ Yes, flawlessly |
| [dart_mutant (Nimblesite)](https://github.com/Nimblesite/dart_mutant) | [dart_mutant.md](dart_mutant.md) | AST (tree-sitter), Rust | Dec 2025 (~8 mo) | 22 | 5 | Good (own site) | ✅ Yes, after a PATH workaround |
| [dart-mutant (SulthanZahran1)](https://github.com/SulthanZahran1/dart-mutant) | [dart_mutant_sulthanzahran.md](dart_mutant_sulthanzahran.md) | AST (tree-sitter), Rust | Aug 2026 (12 days!) | 0 | 2 | Good README | ✅ Yes, surprisingly solid |
| [blight](https://github.com/improvingjef/blight) | [blight.md](blight.md) | AST (Dart analyzer) | Feb 2026 | 0 | 0 | README only | ❌ Crashed, then hung |
| [dart_mutator](https://github.com/andrelramos/dart_mutator) | [dart_mutator.md](dart_mutator.md) | AST (prototype) | May 2021 | 2 | 0 | None | ❌ Non-functional skeleton |

## Key findings

1. **`mutation_test` is the only mature option.** ~5 years old, 14 releases,
   46.9k pub downloads, excellent docs, still maintained (May 2026). It is
   text/regex-based rather than AST-based, so it generates fewer and occasionally
   cruder mutations, and it runs tests serially (slowest of the working tools:
   67 s for 30 mutants). It worked out of the box with zero configuration and
   correctly flagged every gap planted in the sample project.

2. **The likely cause of "didn't work on this machine": Flutter's `dart.bat`.**
   Both Rust-based tools spawn `dart test` as a raw process. On Windows, a
   Flutter-managed PATH only exposes `dart.bat` (a batch wrapper), which Rust's
   `Command::new("dart")` cannot execute → `Error: Failed to run dart test —
   program not found`. **Fix:** put the real SDK dir first on PATH:
   `D:\sdk\flutter\bin\cache\dart-sdk\bin`. After that, both Rust tools ran fine.

3. **Nimblesite's `dart_mutant` is the best of the new generation** — fast
   (37 mutants in ~18 s, parallel), real AST mutations, HTML/Stryker-JSON/JUnit/
   LLM-markdown reports, Scoop/Homebrew packaging, 5 releases over 8 months.
   But it shows its youth: a console display bug (printed "8%" for an 86% score),
   `--junit` silently produced no file, a false "syntax error" warning on the
   modern `library;` directive, and slightly different mutant counts between
   identical runs (32/5 vs 31/6 killed/survived).

4. **SulthanZahran1's `dart-mutant` is 12 days old but technically the most
   ambitious**: 17 operators, per-line coverage routing (skips mutants no test
   covers), TCE equivalent-mutant detection, and a spec-conformant Stryker JSON
   report. It generated 200 mutants (5× more than any other tool) on the same
   code and finished in ~2.5 min. Zero community, zero track record — one bus
   factor, no issue history — but nothing broke in the local run.

5. **Everything else is dead or stillborn.** `blight` (2 commits) crashed with an
   unhandled `TimeoutException` on defaults and hung indefinitely once the
   timeout was raised; `dart_mutator` (2021) is an abandoned 8-commit prototype
   whose `main()` contains a hardcoded path on the author's machine and no logic.

## Round 2: latest-Dart syntax support & internal mechanisms (2026-08-14)

A follow-up probe added `sandbox/lib/src/modern.dart` — 55 lines exercising
Dart 3.0–3.8 features (records, patterns/switch expressions, sealed classes,
extension types, digit separators, wildcard variables, null-aware collection
elements) — and dug into each tool's source. Full details in the per-tool
reports; summary:

| | mutation_test | dart_mutant (Nimblesite) | dart-mutant (SulthanZahran1) |
|---|---|---|---|
| Mechanism | Regex/text replacement (28 builtin rules), pure Dart, serial | True AST via tree-sitter + `tree-sitter-dart` **0.0.4 (May 2024!)** | Regex + hand-written char scanning ("AST-based" claim is false) + **mutant schemata** runner, kernel-diff TCE, coverage routing |
| Runs on Dart 3.13? | ✅ | ✅ (with `dart.bat` PATH fix) | ✅ (with PATH fix) |
| Modern-syntax handling | Never parses → can't break; found only **10 mutants** in the probe file (shallow) | **Parse errors on the probe file**; only ~16 mutants extracted; run completes with healthy-looking score → **silently under-mutates new syntax** | **155 mutants, zero parse issues**, 1 compile-error mutant; syntax-version-agnostic |
| Baseline check | ✅ aborts on red suite | ✅ aborts on red suite | ❌ **none** — produced a report on a known-broken tree |
| Crash hygiene | Restores files | Restores files | Restores files (verified after full runs) |

Key insight on the "regex fragile vs AST maintenance-heavy" question: the AST
tool's cost is real and visible **today** — its grammar is a 2-year-old
third-party crate that already fails on `library;` and everything after
Dart 3.5, and it degrades *silently* (fewer mutants, score still looks fine).
The regex tools can't be broken by new syntax at all; their failure mode is
noisy-but-honest (invalid mutants die as compile errors) or shallow yield.
For someone tracking latest stable Dart, grammar lag is the worse failure mode.

## Recommendation

- **For CI today:** `mutation_test` — boring, documented, stable, quality gate
  built in (exit code + rating), and the only tool installable straight from pub.dev.
- **For faster feedback / better mutations, if you accept some rough edges:**
  Nimblesite `dart_mutant` with the PATH workaround, pinned to v0.5.1 — but be
  aware its 2024-era tree-sitter grammar silently skips post-3.5 syntax.
- **Watch list / best fit if you track latest stable Dart and want maximum
  mutant coverage + Stryker JSON:** SulthanZahran1/dart-mutant — deepest mutant
  generation (155 vs 10–16 on modern code), immune to grammar lag, schemata
  runner. Blockers: 12 days old, zero community, no baseline check (always
  verify the suite is green first).

## Reproducing the local tests

```powershell
# The dart.bat workaround (required for both Rust tools):
$env:PATH = 'D:\sdk\flutter\bin\cache\dart-sdk\bin;' + $env:PATH

cd sandbox
dart run mutation_test --format all               # tool 1 (dev dependency)
..\tools\dart_mutant\dart_mutant.exe --json --ai-report      # tool 2
..\tools\sz_dart_mutant\dart_mutant.exe --format console,json,html,junit  # tool 3
```

Artifacts kept in this repo: `sandbox/` (sample project),
`sandbox/mutation-test-report/` (tool 1 output),
`sandbox/mutation-reports/` (tools 2+3 output, later run overwrote overlapping
filenames), `tools/` (downloaded Windows binaries).
