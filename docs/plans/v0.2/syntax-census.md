# 5. Unhandled-syntax census

- Status: pending
- Decisions: [0016](../../decisions/0016-wide-event-logging.md),
  [0008](../../decisions/0008-composable-mutator-framework.md)

Goal: log which AST node kinds no mutagen handles, and keep the census in the
run result so v1.0 can turn it into the syntax-coverage metric.

## Today

`MutationVisitor` walks once and dispatches per node kind to the registry. A
kind no mutagen claims is skipped in silence, so nobody knows what the tool
cannot see.

## Questions to answer

1. What is the denominator? Every visited kind is mostly noise;
   `SimpleIdentifier` will never have a mutagen. Options:
   - raw census of all visited kinds
   - a curated list of kinds that could carry a mutation
   - kinds some mutagen class targets, counting nodes that yielded none
2. Is a count per kind actionable, or does each need an example location?
3. Does a vetoed `guard()` count as handled? A relational mutagen declining a
   custom `operator >` saw the node and decided. That is not a gap, and
   conflating the two makes the metric lie.
4. Where does it live: the run result, a log event, or both? 0016 wants wide
   events; the v1.0 metric needs the report.

## Steps

- Count in the existing walk; generation must not get a second pass.
- Put the census on `RunResult`, and log the top kinds at run end.
- Run it over this package and over the sandbox, and record both here.

## Success criteria

- Deterministic across runs
  ([0007](../../decisions/0007-deterministic-execution.md)).
- The census names, unprompted, at least the families
  [dart-mutagens.md](dart-mutagens.md) goes on to implement.
- No measurable slowdown of generation.

## Seams for later

- v1.0 syntax coverage is handled over candidate kinds. Keep counts in the
  result and compute the ratio in the report, so the engine never owns a
  metric.
- Stryker JSON has no field for it; the v1.0 HTML and Markdown reports do.

## Result

Pending.
