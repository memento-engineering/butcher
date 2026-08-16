# Pre-v0.1 fixes

Findings from a full code review of `main` (2026-08-16). Fix before the
first pub.dev release ([../../roadmap/v0.1.md](../../roadmap/v0.1.md)).

Each item lists the affected files and the relevant ADR, so it can be
picked up without re-deriving the analysis.

| Doc | Scope | Items |
|---|---|---|
| [correctness.md](correctness.md) | Wrong results or wrong docs | 5 |
| [performance.md](performance.md) | Wasted time before and during runs | 3 |
| [polish.md](polish.md) | Small deviations and robustness gaps | 8 |

Review verdict outside these items: architecture matches the ADRs
(taxonomy, half-life, MSI formulas, deterministic IDs, worker design,
lock lifecycle all check out).
