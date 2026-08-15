import 'dart:io';

import '../model/mutant_result.dart';
import '../model/outcome.dart';
import 'metrics.dart';
import 'report_sink.dart';

/// Prints per-outcome counts and the MSI to a [StringSink].
final class ConsoleReportSink implements ReportSink {
  /// Creates a sink writing to [out]; defaults to stdout.
  ConsoleReportSink({StringSink? out}) : out = out ?? stdout;

  /// Destination of the summary.
  final StringSink out;

  @override
  Future<void> write(List<MutantResult> results) async {
    final metrics = Metrics.fromResults(results);
    out.writeln('${results.length} mutants:');
    for (final outcome in Outcome.values) {
      final count = metrics.counts[outcome];
      if (count != null) out.writeln('  ${outcome.name}: $count');
    }
    out.writeln('MSI: ${metrics.msi.toStringAsFixed(2)}%');
    out.writeln('Covered-code MSI: ${metrics.coveredMsi.toStringAsFixed(2)}%');
    if (metrics.timedOut > 0) {
      out.writeln(
        'Timeout rate: ${metrics.timeoutRate.toStringAsFixed(2)}% '
        '(inconclusive, in neither score)',
      );
    }
  }
}
