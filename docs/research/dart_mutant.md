# dart_mutant (Nimblesite)

- **Website:** https://dartmutant.dev/
- **GitHub:** https://github.com/Nimblesite/dart_mutant
- **License:** MIT
- **Verdict:** ✅ Best of the new generation — fast and genuinely useful, but with visible rough edges. Requires a PATH workaround on Flutter-managed Windows machines.

## Maturity

| Signal | Value |
|---|---|
| Created | December 15, 2025 (~8 months old) |
| Last push | July 2026 (active) |
| GitHub stars / forks | 22 / 5 |
| Releases | **5** (v0.1.0 Dec 2025 → v0.5.1 Jun 2026); Windows binaries since v0.3.0 |
| Open issues | 2 |
| Distribution | Scoop (Windows), Homebrew (macOS/Linux), prebuilt GitHub release binaries, `cargo build` from source. **Not on pub.dev** (it's a Rust binary) |
| Documentation | Good: dedicated website with docs + operator reference, decent README |

Backed by a company (Nimblesite) rather than a single hobbyist, which slightly
improves the maintenance outlook.

## How it works

Written in **Rust**. Parses Dart with **tree-sitter** into an AST and derives
**40+ mutation operators** from it: arithmetic (`+`↔`-`, `*`↔`/`), comparisons
(`>`↔`>=`↔`<` …, `==`↔`!=`), logical (`&&`↔`||`, `!` removal), null-safety
(`??`, `?.`), control flow (if-condition negation), and literals
(`true`↔`false`, string/number tweaks). AST awareness means every mutant is
syntactically valid — no wasted compile-error runs.

Pipeline: scan `lib/` (auto-excluding `*.g.dart`, `*.freezed.dart`,
`*.mocks.dart`, tests) → verify the baseline suite passes → apply one mutation
at a time → run `dart test` (or a custom `--test-command`) **in parallel**
(defaults to CPU count, `-j` to control) → classify killed / survived /
timeout / no-coverage.

Extras: `--sample N` for quick feedback, `--threshold` CI gate,
`--incremental --base-ref main` for changed-files-only runs, result caching,
and optional **AI-assisted mutation placement** (`--ai anthropic` or local LLMs)
to focus mutants on high-value locations.

## Output formats

Default output dir `./mutation-reports/`:

- **HTML** dashboard (default; dark-themed, per-file breakdown, `--open` to launch browser)
- **Stryker-compatible JSON** (`--json`)
- **JUnit XML** (`--junit`) — *see bug below*
- **AI/LLM-optimized Markdown** (`--ai-report`) — surviving mutants with per-mutant "suggested test" guidance; genuinely nice for feeding to a coding assistant
- Console summary with score bar

## Local test (Windows 11, Dart 3.13, v0.5.1)

Installed by downloading `dart_mutant-v0.5.1-x86_64-pc-windows-msvc.zip` from
GitHub releases (Scoop not present on this machine); binary in `tools/dart_mutant/`.

**First run failed** — and this is very likely the "didn't work on this machine"
failure mode: `Error: Failed to run dart test — program not found`. The Rust
process spawner cannot execute `dart.bat` (the only `dart` on a Flutter-managed
Windows PATH). **Workaround:** prepend the real SDK directory:

```powershell
$env:PATH = 'D:\sdk\flutter\bin\cache\dart-sdk\bin;' + $env:PATH
```

After that it ran well:

- 37 mutants across the 3 sandbox files; baseline verified first.
- Run 1: 32 killed / 5 survived; Run 2 (identical input): 31 killed / 6 survived — **~84–86% score, but nondeterministic between runs**.
- **Runtime: ~18–20 s** with 16 parallel jobs (vs. 66 s for 30 mutants with `mutation_test`).
- All survivors were in the intentionally weak `DiscountService`, with correct boundary/operator diagnoses.
- The AI markdown report was the standout: each surviving mutant comes with a concrete suggestion for the missing test case.

### Bugs observed locally

1. **`dart.bat` spawn failure** (above) — blocker until PATH is fixed; no hint in the error message.
2. **Console score display bug:** printed `8%` under a progress bar that clearly showed ~86%; the JSON/HTML/AI reports had the correct 83.8%.
3. **`--junit` produced no file** despite being accepted.
4. **False `tree-sitter reported syntax errors` warning** on `lib/sandbox.dart`, which only contains the modern bare `library;` declaration — the grammar seems to lag current Dart syntax.
5. **Run-to-run variance** in mutant classification (see above), presumably a race in parallel execution.

## Internals & modern-syntax support (deep dive, 2nd session)

Rust, with parsing delegated to **`tree-sitter` 0.24 + `tree-sitter-dart`
0.0.4** from crates.io. That grammar version was **published May 2024** — it
predates digit separators (Dart 3.6), wildcard variables (3.7), null-aware
collection elements (3.8) and even chokes on the bare `library;` directive.
A newer grammar exists (0.2.0, April 2026, nielsenko/tree-sitter-dart), but
dart_mutant hasn't upgraded to it. This is the structural risk of the
tree-sitter approach: **the community grammar always trails the language**, and
the tool inherits that lag.

**Empirical probe:** against a file exercising Dart 3.0–3.8 features (records,
patterns, switch expressions, sealed classes, extension types, digit
separators, wildcards, null-aware elements), it logged
`WARN tree-sitter reported syntax errors; mutation discovery may be incomplete`
and extracted only **~16 mutants** from the most operator-dense file in the
project (SulthanZahran1's tool found **155**; even regex-based mutation_test's
low yield was honest about nothing being skipped). The run then completes
normally with a healthy-looking score.

**This failure mode matters if you track latest stable Dart:** it doesn't
crash on new syntax — it **silently mutates less of your code** while the
reported mutation score still looks trustworthy. Everything the grammar can't
parse is invisible to the tool, and one WARN line in the log is the only hint.

Runner mechanics (solid): baseline verification before mutating (aborts
correctly on a red suite), one file-rewrite per mutant, parallel `dart test`
child processes (defaults to CPU count), timeout classification, file
restoration afterwards — confirmed clean restoration in all local runs.

## Assessment

The core loop is solid and the speed advantage over `mutation_test` is large.
The bugs are cosmetic-to-annoying rather than corrupting, but items 1 and 5
would erode trust in CI. Usable today for local/interactive work if you pin
v0.5.1 and apply the PATH fix; keep an eye on releases.
