# 3. Config file and globs

- Status: pending
- Decision: needs a new ADR; the schema is public API from the moment it ships

Goal: a project states its rad settings once. Include/exclude globs decide
what gets mutants.

## Questions to answer

1. Where does it live? A `rad.yaml` at the project root, a
   `radioactive_dart:` section in `pubspec.yaml`, or an
   `analysis_options`-style file with includes. Pick one; renaming it later
   breaks every consumer.
2. What happens to `.radignore`? Copy exclusions and mutation include/exclude
   are different questions
   ([0004](../../decisions/0004-shadow-copy-isolation.md)) — decide whether
   they stay separate or the config subsumes both.
3. Precedence is CLI over config over defaults. What does a negatable flag
   mean when the config disagrees, and can the CLI turn something back on?
4. Does the file carry a schema version, or is additive-only enough?
5. Unknown keys: error or warning? A silently ignored typo is a silently
   different run.

## Names to reserve now

| Key | Ships | Meaning |
|---|---|---|
| `include` / `exclude` | v0.2 | globs over `lib/` that mutants come from |
| `jobs` | v0.2 | parallel workers |
| `threshold` / `max-timeouts` | v0.2 | gates |
| `coverage` / `collect-coverage` | v0.2 | coverage sources |
| `non-interactive` | v0.2 | lock conflicts abort |
| `diff-base` | v1.0 | incremental selection at line granularity |
| `strategy` | v1.0 | beamline or subprocess |
| `report` | v1.0 | sinks: Stryker JSON, HTML, Markdown |
| `mutagens` | later | which operators are active |

Reserving costs nothing; the last two are named, not implemented.

## Steps

- ADR first: location, precedence, unknown-key handling, compatibility rule.
- Parse and validate before anything else runs, so a bad config fails before a
  containment is copied.
- Document the keys in README for users and the ADR for maintainers, without
  either leaking into the other.

## Success criteria

- Every key has a round-trip test: config alone, CLI alone, both disagreeing.
- An unknown key aborts with the key and its location.
- Globs are matched against project-relative posix paths, like every other
  path in the tool.

## Seams for later

- v1.0 adds keys and never renames one. The ADR must say so, so the rule
  outlives whoever wrote it.
- `report` is a list from the start: sinks are additive
  ([v1.0](../../roadmap/v1.0.md)) and must not turn into a boolean per format.
- `strategy` exists so a Flutter project can be told to stay on subprocesses
  before the beamline ships.

## Result

Pending.
