# Pre-v0.1 fixes

- Status: all 21 items fixed (2026-08-18), kept as the record of what changed.

Findings from a full code review of `main` (2026-08-16), fixed before the
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

## Resolution

Each item was fixed on its own branch, reviewed by an agent hunting for
planted defects, then judged again after merge. Those rounds found nine
further defects, all fixed; the ones worth remembering:

| Where | Defect found after the fix |
|---|---|
| Correctness 1 | the guard's own test pinned a viable mutant as dropped |
| Correctness 12 | `setsid` broke every macOS run; later, a missing `ps` killed nothing |
| Performance 2 | any-depth excludes pruned `lib/**/build/`, desyncing generation |
| Performance 4 | a 64 KiB cap truncated the parsed event stream at ~160 tests |
| Correctness 5 | the narrowed catch let an exception strand the run lock |

Two decisions deviate from the text above:

- Item 8's matcher stayed hand-written: `package:ignore` does not exist.
- Item 12 kills the tree best effort from a `ps` snapshot, not a process
  group ([ADR 0006](../../decisions/2026-08-14-outcome-taxonomy.md)); `setsid` is
  absent from minimal images and Dart cannot spawn a process group.

A final review of the complete fix range found five remaining defects:

| Area | Defect |
|---|---|
| Mutagens | identity swaps escaped through extensions; numeric context lost `/` |
| Output | the raw-output cap still preceded reporter-event parsing |
| Provisioning | existing but stale package configuration skipped `pub get` |
| Lifecycle | initial logging still ran outside lock-release protection |

All five have regression coverage and are fixed.
