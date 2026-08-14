import '../model/mutant_result.dart';

/// Consumes the results of a run (console summary, Stryker JSON, ...).
abstract interface class ReportSink {
  Future<void> write(List<MutantResult> results);
}
