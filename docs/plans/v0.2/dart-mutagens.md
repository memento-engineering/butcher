# 6. Dart-specific mutagens

- Status: pending
- Decisions: [0008](../../decisions/2026-08-14-composable-mutator-framework.md),
  [0019](../../decisions/2026-08-16-static-viability-filtering.md)
- Needs: [syntax-census.md](syntax-census.md)

Goal: mutate the parts of Dart the operator families miss. Which families,
the census decides.

## Candidates

| Family | Mutation | Known risk |
|---|---|---|
| Collection elements | drop a spread, negate an `if` element, drop a `for` element | low; span replacement, usually viable |
| Type test | `is` → `is!` | strands promotions; reuse `promotion_dependence.dart` |
| Assignment | `+=` → `-=`, and peers | mirrors the arithmetic mutagen |
| Increment | `++` → `--` | prefix/postfix swaps are often equivalent |
| Conditional | swap `?:` branches, force one | overlaps null injection |
| Cascade | drop a cascade section | `..` → `.` changes the expression type |
| Async | drop an `await` | changes `Future<T>` to `T`; viable only where the value is unused |
| String literal | `'x'` → `''` | high volume, low signal |

## Questions to answer

1. Which families does the census actually justify, and which are guesses?
2. What is each family's unviable rate on this package? A family that is
   mostly non-compiling costs analysis time and reports nothing, even though
   0019 drops it before a suite runs.
3. Which families produce equivalent mutants often enough to hurt the score's
   honesty ([0013](../../decisions/2026-08-14-score-and-honesty-metrics.md)) before
   TCE lands in v2.0 ([0012](../../decisions/2026-08-14-tce-equivalent-detection.md))?
4. Which need guards beyond `promotion_dependence.dart`?

## Steps

- One family per commit: mutagen, guard, unit tests.
- After each, a self-run: mutant count, unviable rate, survivors, MSI change.
- Fill the table above with measurements, and drop families that fail
  question 2.

## Success criteria

- Every family lands with its guard tests, or does not land.
- MSI movement is explained, not merely reported.
- No family raises generation time out of proportion to the mutants it adds.

## Seams for later

- One file per mutagen, registered in `MutagenRegistry`; the framework shape
  does not change.
- Schemata ([0010](../../decisions/2026-08-14-mutant-schemata.md)) need a mutation
  to be selectable by a runtime value, so the mutated and original code must
  coexist in one build. A family that only works by rewriting a file will not
  survive the beamline: record, per family, whether it is expressible as a
  guarded expression.
- Statement-level removal (`await`, cascade sections) is the family most at
  risk of that, and is the reason to measure it before building on it.

## Result

Pending.
