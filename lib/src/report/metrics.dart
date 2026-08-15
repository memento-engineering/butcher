import '../model/mutant_result.dart';
import '../model/outcome.dart';

/// Score and honesty metrics over one run (ADR 0013).
final class Metrics {
  /// Computes metrics from classified [results].
  Metrics.fromResults(List<MutantResult> results) {
    for (final result in results) {
      counts[result.outcome] = (counts[result.outcome] ?? 0) + 1;
    }
  }

  /// Mutant count per outcome; absent outcomes have no entry.
  final Map<Outcome, int> counts = {};

  int _count(Outcome outcome) => counts[outcome] ?? 0;

  /// Mutants the suite detected: killed or timed out.
  int get detected => _count(Outcome.killed) + _count(Outcome.timeout);

  /// Mutants that escaped: survived or uncovered.
  int get undetected => _count(Outcome.survived) + _count(Outcome.noCoverage);

  /// Mutation score indicator in percent; 100 when nothing was scoreable.
  double get msi => _percent(detected, detected + undetected);

  /// MSI over covered code only; equals [msi] under full coverage.
  double get coveredMsi =>
      _percent(detected, detected + _count(Outcome.survived));

  static double _percent(int part, int whole) =>
      whole == 0 ? 100 : part / whole * 100;
}
