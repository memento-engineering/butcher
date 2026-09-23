# Fixtures

`mutation-testing-report-schema.json` is a verbatim copy of the published
mutation-testing report schema, taken from the `stryker-mutator/
mutation-testing-elements` repository at
`packages/report-schema/src/mutation-testing-report-schema.json`. It is the
authority `schema_conformance_test.dart` checks the models against. Refresh it
from upstream, never hand-edit it: an edit that makes a diverging model pass is
the one failure this fixture exists to catch.

`full_report.json` is a report document exercising every field at every nesting
level, including all eight statuses and both a minimal and a fully populated
mutant. `golden_report_test.dart` parses it through both entry points and emits
it again, so a field the models silently drop reds the suite.
