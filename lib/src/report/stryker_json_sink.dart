import 'dart:convert';
import 'dart:io';

import '../model/mutant_result.dart';
import '../model/outcome.dart';
import 'report_sink.dart';

/// Writes the Stryker `mutation-testing-report-schema` JSON (ADR 0009).
final class StrykerJsonSink implements ReportSink {
  /// Creates a sink over generation-time [sources], writing [outputPath].
  const StrykerJsonSink({required this.sources, required this.outputPath});

  /// Pristine source per irradiated file; offsets refer to these texts.
  final Map<String, String> sources;

  /// Destination file of the JSON report.
  final String outputPath;

  /// Stryker status per outcome; unthemed interop names (ADR 0014).
  static const statusOf = {
    Outcome.killed: 'Killed',
    Outcome.survived: 'Survived',
    Outcome.noCoverage: 'NoCoverage',
    Outcome.timeout: 'Timeout',
    Outcome.unviable: 'CompileError',
    Outcome.runError: 'RuntimeError',
    Outcome.memoryError: 'RuntimeError',
    Outcome.equivalent: 'Ignored',
  };

  @override
  Future<void> write(List<MutantResult> results) async {
    final files = <String, Map<String, Object>>{};
    for (final result in results) {
      final mutation = result.mutant.mutation;
      final file = files.putIfAbsent(
        mutation.filePath,
        () => {
          'language': 'dart',
          'source': sources[mutation.filePath] ?? '',
          'mutants': <Object>[],
        },
      );
      final source = file['source']! as String;
      (file['mutants']! as List<Object>).add({
        'id': result.mutant.id,
        'mutatorName': mutation.operatorId,
        'replacement': mutation.replacement,
        'description': mutation.description,
        'location': {
          'start': _position(source, mutation.offset),
          'end': _position(source, mutation.offset + mutation.length),
        },
        'status': statusOf[result.outcome]!,
      });
    }

    final report = File(outputPath);
    report.parent.createSync(recursive: true);
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': '1',
        'thresholds': {'high': 80, 'low': 60},
        'files': files,
      }),
    );
  }

  static Map<String, int> _position(String source, int offset) {
    var line = 1;
    var lineStart = 0;
    for (var i = 0; i < offset; i++) {
      if (source.codeUnitAt(i) == 0x0A) {
        line++;
        lineStart = i + 1;
      }
    }
    return {'line': line, 'column': offset - lineStart + 1};
  }
}
