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
///
/// The schema's test-attribution fields — `coveredBy`, `killedBy` and
/// `testsCompleted` — are deliberately left unset. The runner carries no
/// per-test identity: it reports a suite's events, not which named test
/// covered a mutant or which one killed it, so writing those fields would
/// mean inventing them. The schema distinguishes an absent optional from an
/// empty one, and absent is the honest answer until the runner can name
/// tests.
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
  /// no memory status of its own. That collapse stays; [statusReasonFor] is
  /// what keeps it from erasing which of the two happened.
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

  /// Why [result] carries the status [statusOf] gives it, or `null` when the
  /// status already says everything the document can say.
  ///
  /// Three outcomes need a reason, and for two different sorts of reason.
  /// [Outcome.runError] and [Outcome.memoryError] share the `RuntimeError`
  /// wire status, so without one the document cannot tell a process that
  /// crashed from one that ran out of memory. [Outcome.unviable] shares its
  /// status with nothing, but `CompileError` on its own never says whether
  /// the mutant failed to compile or the tool did, so it is just as opaque
  /// unexplained.
  ///
  /// [Outcome.memoryError] is RESERVED. The taxonomy declares it and this
  /// mapping covers it, but no classification path in the tool assigns it
  /// today and nothing captures a memory-specific diagnostic, so its reason
  /// names the category and nothing more. A producer that can actually raise
  /// the outcome is what earns it a measured reason.
  static String? statusReasonFor(MutantResult result) =>
      switch (result.outcome) {
        Outcome.runError => _runErrorReason(result),
        Outcome.memoryError =>
          'The test process ran out of memory. Reserved: no classification '
              'path assigns this outcome yet.',
        Outcome.unviable =>
          'The mutant does not compile; its test suite failed to load.',
        Outcome.killed ||
        Outcome.survived ||
        Outcome.noCoverage ||
        Outcome.timeout ||
        Outcome.equivalent => null,
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
              // The test run already measured this; the schema wants
              // milliseconds. Absent when no tests ran for the mutant.
              duration: result.testRun?.duration.inMilliseconds,
              replacement: mutation.replacement,
              statusReason: statusReasonFor(result),
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

  /// The reason for an [Outcome.runError], carrying the diagnostic the
  /// classification path captured when there is one.
  static String _runErrorReason(MutantResult result) {
    const summary = 'The test process failed without reporting a test failure.';
    final detail = _firstLine(result.error ?? result.testRun?.errorOutput);
    return detail == null ? summary : '$summary $detail';
  }

  /// The first non-blank line of [diagnostic], bounded so a stack trace
  /// cannot push a whole process dump into the document.
  static String? _firstLine(String? diagnostic) {
    if (diagnostic == null) return null;
    for (final line in const LineSplitter().convert(diagnostic)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.length <= _reasonDetailLimit
          ? trimmed
          : '${trimmed.substring(0, _reasonDetailLimit)}...';
    }
    return null;
  }

  /// Longest captured diagnostic a status reason quotes.
  static const _reasonDetailLimit = 200;

  static Position _position(LineIndex index, int offset) =>
      Position(line: index.lineAt(offset), column: index.columnAt(offset));
}
