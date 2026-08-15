# Changelog

## 0.1.0-dev

- Package scaffold: core value objects and public seam interfaces.
- MVP engine: mutant generation, containment isolation, background reading,
  half-life timeouts, outcome classification.
- Core mutagens: arithmetic, relational, equality, logical, boolean literal.
- Console summary (MSI, covered-code MSI) and Stryker JSON report.
- `rad` CLI with `--threshold` criticality gate and `--output`.
- `.radignore` consumer exclusions for the containment copy.
- Wide-event CLEF logging to a temp-dir log file; `--verbose` renders
  events human-readably with colors. Per-mutant run logs are kept separately.
- Parallel classification: `--jobs` workers, each with its own containment.
