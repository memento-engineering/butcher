import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';

/// Reads a Stryker report, counts what survived, and writes the parsed tree
/// back out.
///
/// The package does no I/O of its own: opening the files is the caller's job,
/// which is what lets a dashboard or a CI gate take the schema without taking
/// the mutation engine.
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

  for (final mutant in survived) {
    final start = mutant.location.start;
    print(
      '  ${mutant.id} ${mutant.mutatorName} @ ${start.line}:${start.column}',
    );
  }

  File('reports/copy.json').writeAsStringSync(jsonEncode(report.toJson()));
}
