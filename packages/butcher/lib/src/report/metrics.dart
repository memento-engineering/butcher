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

  /// Mutants a failing test detected.
  int get killed => _count(Outcome.killed);

  /// Mutants that escaped every test that ran.
  int get survived => _count(Outcome.survived);

  /// Mutants no test covers; never executed.
  int get uncovered => _count(Outcome.noCoverage);

  /// Mutants whose run exceeded its deadline: an inconclusive peer of
  /// killed and survived, in neither MSI term (ADR 0013).
  int get timedOut => _count(Outcome.timeout);

  /// Mutation score indicator in percent; null when nothing was scoreable.
  double? get msi => _percent(killed, killed + survived + uncovered);

  /// MSI over covered code only; equals [msi] under full coverage.
  double? get coveredMsi => _percent(killed, killed + survived);

  /// Share of conclusive-or-timed-out mutants that timed out, in percent.
  double get timeoutRate =>
      timedOut == 0 ? 0 : timedOut / (killed + survived + timedOut) * 100;

  static double? _percent(int part, int whole) =>
      whole == 0 ? null : part / whole * 100;
}
