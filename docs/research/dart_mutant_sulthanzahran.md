# dart-mutant (SulthanZahran1)

- **GitHub:** https://github.com/SulthanZahran1/dart-mutant
- **License:** MIT (per release metadata)
- **Verdict:** ⚠️ Technically the most ambitious tool — and it worked flawlessly in the local test — but it is **12 days old** with zero community. Watch list, not production.

Note: same binary name (`dart_mutant.exe`) as the unrelated Nimblesite project —
easy to confuse, and possibly deliberate SEO. They share no code lineage that I
could see, though both are Rust + tree-sitter.

## Maturity

| Signal | Value |
|---|---|
| Created | **August 2, 2026 — 12 days before this research** |
| Last push | August 3, 2026 |
| GitHub stars / forks | 0 / 0 |
| Releases | 2 (v0.1.0 on Aug 2, **v1.0.0 on Aug 3** — a 1.0 one day after the first release says more about versioning enthusiasm than stability) |
| Open issues | 1 |
| Distribution | Prebuilt binaries for Windows/macOS (x64+ARM)/Linux on GitHub releases; not on pub.dev, no package-manager integration yet |
| Documentation | Good README (config precedence, operator list, examples); no website; no issue/PR history to learn from |

Single-author, brand-new, zero adoption. Bus factor of one.

## How it works

> **Correction from the deep dive:** the repo description says "AST-based",
> but the source says otherwise — see *Internals* below. It is a regex +
> hand-written-scanner tool with a very sophisticated *runner*, not an AST
> mutator.

Feature set (the most academic of the five projects):

- **17 mutation operators**, including Dart-specific ones: null-safety (`??`,
  `?.`), cascades, async/await, streams, sealed classes, plus the classic AOR
  (arithmetic operator replacement), ROR (relational operator replacement),
  SDL (statement deletion), etc. Operators are selectable via `--operators AOR,ROR,...`.
- **Coverage routing:** collects per-line test coverage first and marks mutants
  on uncovered lines as `NoCoverage` instead of wasting a test run on them.
- **TCE (Trivial Compiler Equivalence) detection** (`--detect-equivalent`) to
  filter out equivalent mutants — a feature most mainstream tools (including
  Stryker itself) don't have.
- Config from CLI flags → `.dart_mutant.yml` → built-in defaults; `--threshold`
  CI gate; `--incremental --base-ref`; `--sample N`; re-run a single mutant by
  ID; parallel workers default to CPU count; auto-detects `dart test` vs
  `flutter test`.

## Output formats

`--format` takes a comma-separated list; all four verified locally:

- **console** — summary with MSI (Mutation Score Indicator) and mutation coverage
- **json** — **spec-conformant Stryker `mutation-testing-report-schema` v2** (works with Stryker's report viewer tooling)
- **html** — report dashboard
- **junit** — JUnit XML (survivors = failures, no-coverage = skipped)

## Local test (Windows 11, Dart 3.13, v1.0.0)

Downloaded `dart_mutant-x86_64-pc-windows-msvc.zip` from releases into
`tools/sz_dart_mutant/`. Needs the same **`dart.bat` PATH workaround** as the
Nimblesite tool (real `dart.exe` dir first on PATH), then:

```powershell
dart_mutant.exe --path . --format console,json,html,junit
```

Results on the sandbox project:

- **200 mutants generated** — 5–7× more than the other tools on identical code (109 in `calculator.dart`, 90 in `discount.dart`), reflecting the larger operator set.
- 150 killed, 6 survived, **42 routed away as NoCoverage** (coverage routing visibly working), 2 compile errors (so its AST mutations aren't always valid — minor).
- **MSI 96.2%**, mutation coverage 78.8%; per-file scores in the JSON (calculator 86.2%, discount 62.2% — correctly ranking the weak file lowest).
- Runtime roughly ~2.5 min for 200 mutants incl. coverage collection — slower in total than Nimblesite but far more mutants; per-mutant throughput is comparable.
- All four report files generated correctly; the Stryker JSON validated against the expected schema shape (`schemaVersion: "2"`, statuses `Killed`/`Survived`/`NoCoverage`).
- No crashes, no display bugs observed. Honestly the cleanest run of the three working tools.

## Internals & modern-syntax support (deep dive, 2nd session)

Reading the source (5-crate Rust workspace: core / runner / report / tce / cli)
reveals the **"AST-based" claim in the GitHub description is not true**:
`dart-mutant-core`'s only parsing dependency is the `regex` crate — no
tree-sitter, no grammar. Operators are implemented as per-category modules
(arithmetic, relational, logical, null_safety, cascade, async_await, stream,
sealed_class, …) using **regexes plus hand-written character scanning** with an
`is_in_string_or_comment()` guard. So mechanically it is closer to
`mutation_test` than to Nimblesite's tool — just with far more aggressive
patterns (hence 155 vs 10 mutants on the same file).

Where it is genuinely advanced is the **runner**:

- **Mutant schemata** (`schemata.rs`): instead of rewrite-compile-test per
  mutant, *all* mutations are injected into the source at once as conditional
  branches selected by `const String.fromEnvironment('DART_MUTANT_ID')`. The
  project compiles **once** and runs N times with different IDs — this is why
  355 mutants finish in minutes. (Also why an occasional schemata transform
  doesn't compile: 1 of 355 mutants errored locally.)
- **TCE** (`dart-mutant-tce`): detects equivalent mutants by compiling to Dart
  kernel and comparing output — a technique from the research literature that
  even Stryker doesn't ship.
- **Coverage routing**: per-line coverage collected first; mutants on
  uncovered lines are marked `NoCoverage` and never executed.

**Modern-syntax probe:** on the Dart 3.0–3.8 feature file (records, patterns,
switch expressions, sealed classes, extension types, digit separators,
wildcards, null-aware elements) it found **155 mutants, zero parse issues,
1 compile-error mutant** — by far the best coverage of modern code, precisely
*because* it never parses: regex scanning is syntax-version-agnostic.

**Stability caveat found locally:** it performs **no baseline verification**.
When the working tree accidentally contained a broken source file (leftover
from blight's crash), both other tools refused to run — this one happily
produced a full report with a subtly wrong score. Always run it on a
known-green suite.

## Assessment

Feature-wise this is what a "Stryker for Dart" should look like: coverage
routing, TCE, real Stryker reports, Dart-3-aware operators. But a project that
went 0.1.0 → 1.0.0 in one day, has zero users, and has existed for less than
two weeks cannot be trusted with CI duty yet. Re-evaluate in 6 months: if it's
still maintained and has gathered users/issues, it likely leapfrogs both
alternatives.
