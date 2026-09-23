import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';

import '../model/line_index.dart';
import '../model/mutant_result.dart';
import '../model/outcome.dart';
import 'report_sink.dart';

/// Writes the Stryker `mutation-testing-report-schema` JSON (ADR 0009).
///
/// The document is built as `butcher_report`'s typed [MutationTestResult] and
/// serialised by that package, so nothing here shapes the schema by hand; the
/// sink's only I/O remains the single file write.
final class StrykerJsonSink implements ReportSink {
  /// Creates a sink over generation-time [sources], writing [outputPath].
  const StrykerJsonSink({required this.sources, required this.outputPath});

  /// Pristine source per mutated file; offsets refer to these texts.
  final Map<String, String> sources;

  /// Destination file of the JSON report.
  final String outputPath;

  /// Stryker status per outcome; unthemed interop names (ADR 0014).
  ///
  /// The eight outcomes map onto seven statuses: [Outcome.runError] and
  /// [Outcome.memoryError] both carry `RuntimeError`, because the schema has
  /// no memory status of its own.
  ///
  /// The values are [MutantStatus], whose [MutantStatus.wireName] is the
  /// exact spelling the document carries, so the wire names are the schema
  /// package's rather than a second copy of them here.
  static const statusOf = {
    Outcome.killed: MutantStatus.killed,
    Outcome.survived: MutantStatus.survived,
    Outcome.noCoverage: MutantStatus.noCoverage,
    Outcome.timeout: MutantStatus.timeout,
    Outcome.unviable: MutantStatus.compileError,
    Outcome.runError: MutantStatus.runtimeError,
    Outcome.memoryError: MutantStatus.runtimeError,
    Outcome.equivalent: MutantStatus.ignored,
  };

  @override
  Future<void> write(List<MutantResult> results) async {
    final sourceOf = <String, String>{};
    final mutantsOf = <String, List<ReportMutant>>{};
    final indexes = <String, LineIndex>{};
    for (final result in results) {
      final mutation = result.mutant.mutation;
      final path = mutation.filePath;
      final source = sourceOf.putIfAbsent(path, () => sources[path] ?? '');
      final index = indexes.putIfAbsent(path, () => LineIndex(source));
      mutantsOf
          .putIfAbsent(path, () => <ReportMutant>[])
          .add(
            ReportMutant(
              id: result.mutant.id,
              mutatorName: mutation.mutatorId,
              location: Location(
                start: _position(index, mutation.offset),
                end: _position(index, mutation.offset + mutation.length),
              ),
              status: statusOf[result.outcome]!,
              description: mutation.description,
              replacement: mutation.replacement,
            ),
          );
    }

    final document = MutationTestResult(
      schemaVersion: '1',
      thresholds: const Thresholds(high: 80, low: 60),
      files: {
        for (final entry in mutantsOf.entries)
          entry.key: FileResult(
            language: 'dart',
            source: sourceOf[entry.key]!,
            mutants: entry.value,
          ),
      },
    );

    final report = File(outputPath);
    report.parent.createSync(recursive: true);
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document.toJson()),
    );
  }

  static Position _position(LineIndex index, int offset) =>
      Position(line: index.lineAt(offset), column: index.columnAt(offset));
}
