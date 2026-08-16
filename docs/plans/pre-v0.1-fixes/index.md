# Pre-v0.1 fixes

Findings from a full code review of `main` (2026-08-16). Fix before the
first pub.dev release ([../../roadmap/v0.1.md](../../roadmap/v0.1.md)).

Each item lists the affected files and the relevant ADR, so it can be
picked up without re-deriving the analysis.

| Doc | Scope | Items |
|---|---|---|
| [correctness.md](correctness.md) | Wrong results, gates, or execution | 13 |
| [performance.md](performance.md) | Wasted time or memory | 4 |
| [polish.md](polish.md) | Release, lifecycle, and logging gaps | 4 |

Review verdict outside these items: taxonomy, half-life formulas,
deterministic IDs, and worker result ordering match their ADRs.
