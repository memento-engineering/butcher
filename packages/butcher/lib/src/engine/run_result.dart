import '../model/mutant_result.dart';

/// Everything a finished run produced.
final class RunResult {
  /// Creates a result over classified [results] and run timings.
  const RunResult({
    required this.results,
    required this.sources,
    required this.baseline,
    required this.deadline,
  });

  /// One classified result per generated mutant.
  final List<MutantResult> results;

  /// Pristine source per irradiated file, captured at generation time.
  final Map<String, String> sources;

  /// Duration of the green baseline suite run (ADR 0005).
  final Duration baseline;

  /// Per-mutant timeout derived from the baseline (ADR 0006).
  final Duration deadline;
}
