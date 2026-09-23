# butcher_report

The Stryker mutation-report schema, split out of the [butcher](../butcher)
mutation engine so a consumer can read or write the report without taking the
engine.

Stryker's JSON report is butcher's primary output format, which makes its
shape a contract rather than an implementation detail: a dashboard or a CI
gate should be able to parse it without depending on the tool that produced
it.

## What is here

Every type of the draft-07 `MutationTestResult` schema, at all four nesting
levels, with its required fields enforced on parse and its optional fields
omitted — never written as null — on emit. `MutantStatus` carries all eight
wire spellings, including `Pending`, which butcher never emits but another
producer may.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';

void main() {
  final report = parseMutationTestReport(
    File('reports/mutation.json').readAsStringSync(),
  );
  final survived = <ReportMutant>[
    for (final file in report.files.values)
      for (final mutant in file.mutants)
        if (mutant.status == MutantStatus.survived) mutant,
  ];
  print('${survived.length} mutants survived');

  File('reports/copy.json').writeAsStringSync(jsonEncode(report.toJson()));
}
```

The package itself does no file and no network I/O: the two entry points take
a JSON string or an already-decoded map, and `toJson` returns a map. Opening
the files above is the caller's job, as the example shows. Every type compares
by value, hand-written, so a CLI toolchain takes no code-generation
dependency to use them.

`test/fixtures/mutation-testing-report-schema.json` is a verbatim copy of the
published schema, and the suite checks the models against it rather than
against prose.

## License

MIT, derived from the upstream `radioactive_dart` package — see
[LICENSE](LICENSE).
