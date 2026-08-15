# Architecture decision records

Decisions distilled from the tool survey in [../research/](../research/index.md)
and mature tools in other ecosystems
([../research/other-ecosystems.md](../research/other-ecosystems.md)).

How the decisions compose at runtime:

```mermaid
flowchart TD
    A[containment: filtered project or workspace copy] --> B[background reading: verify suite green]
    B --> C[analyzer: resolved AST → mutants]
    C --> D[tracer: collect or ingest per-test lcov]
    D --> E[compile schemata once]
    E --> F[per mutant: covering tests, fastest first, first kill wins]
    F --> G[TCE pass over survivors]
    G --> H[reports + criticality gate]
```

| ADR | Title | Status |
|---|---|---|
| [0001](0001-implement-in-dart.md) | Implement in Dart | accepted |
| [0002](0002-parse-with-official-analyzer.md) | Parse with the official analyzer | accepted |
| [0003](0003-distribution-and-sdk-resolution.md) | Distribution and SDK resolution | accepted |
| [0004](0004-shadow-copy-isolation.md) | Containment isolation | accepted |
| [0005](0005-mandatory-baseline-verification.md) | Mandatory background reading | accepted |
| [0006](0006-outcome-taxonomy.md) | Outcome taxonomy | accepted |
| [0007](0007-deterministic-execution.md) | Deterministic execution | accepted |
| [0008](0008-composable-mutator-framework.md) | Composable mutagen framework | accepted |
| [0009](0009-stryker-json-primary-report.md) | Stryker JSON as primary report | accepted |
| [0010](0010-mutant-schemata.md) | Mutant schemata | accepted, planned v1.0 |
| [0011](0011-per-test-coverage-routing.md) | Tracer coverage routing | accepted, planned v1.0 |
| [0012](0012-tce-equivalent-detection.md) | TCE equivalent-mutant detection | accepted, planned v2.0 |
| [0013](0013-score-and-honesty-metrics.md) | Score and honesty metrics | accepted |
| [0014](0014-naming-and-vocabulary.md) | Naming and vocabulary | accepted |
| [0015](0015-full-pana-score.md) | Full pana score | accepted |
| [0016](0016-wide-event-logging.md) | Wide-event logging | accepted |
| [0017](0017-parallel-classification.md) | Parallel classification | accepted |

Feature staging: [../roadmap/index.md](../roadmap/index.md).
