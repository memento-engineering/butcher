# 0014: Naming and vocabulary

- Status: accepted

## Context

- The project needs one vocabulary across docs, CLI, and reports.
- Radiobiology natively contains the industry terms: radiation is the
  canonical physical mutagen, and irradiation yields mutants (Muller, 1946).
  Every other theme would have to translate them.
- Prior art claims other metaphors: Stryker (X-Men), Infection (disease),
  Cosmic Ray (Python, radiation).

## Decision

- Package: `radioactive_dart`. CLI executable: `rad`.
- Theme: radiobiology. Radiation physics names the apparatus (what the tool
  does); radiation effects name the subject (what happens to the code).
- A themed name must predict the mechanics it names.

| Concept | Term |
|---|---|
| Mutated code variant | mutant |
| Mutation operator ([0008](0008-composable-mutator-framework.md)) | mutagen |
| Applying mutants to source | irradiation |
| Isolated project copy ([0004](0004-shadow-copy-isolation.md)) | containment |
| Green-suite verification run ([0005](0005-mandatory-baseline-verification.md)) | background reading |
| Per-mutant timeout budget ([0006](0006-outcome-taxonomy.md)) | half-life |
| Per-test coverage routing ([0011](0011-per-test-coverage-routing.md)) | tracer |
| Surviving mutants of a run | fallout |
| Score threshold gate | criticality gate |

Unthemed, for interop and clarity:

- Outcome enum ([0006](0006-outcome-taxonomy.md)): `Killed` … `Equivalent`.
- Stryker JSON field names ([0009](0009-stryker-json-primary-report.md)).
- "Schemata" ([0010](0010-mutant-schemata.md)), "mutation score" / MSI.
- CLI flag names (`--threshold`, `--with-timeouts`).

`rad` collision check (2026-08):

- Dart: no SDK tool or pub package ships a `rad` executable; the pub package
  `rad` (dormant web framework) declares none.
- PATH elsewhere: Radicle and Radius CLIs both install `rad`;
  `dart run radioactive_dart` stays the unambiguous form.

## Rejected

- Reactor / control rods for schemata: rods throttle the whole core;
  schemata selects one branch of N. The name predicts the wrong mechanics.
- Hot cell for the isolated copy: containment is plainer.
- Biological machinery terms (gene expression, silent mutation, apoptosis):
  the subject keeps only standard radiation-effect terms.
- Alternative themes (immunology, espionage, alchemy, changeling): each must
  rename "mutant" and fight the standard vocabulary.
