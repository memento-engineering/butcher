import '../model/mutant_result.dart';

/// Everything a finished run produced.
final class RunResult {
  /// Creates a result over classified [results] and run timings.
  const RunResult({
    required this.results,
    required this.sources,
    required this.backgroundReading,
    required this.halfLife,
  });

  /// One classified result per generated mutant.
  final List<MutantResult> results;

  /// Pristine source per irradiated file, captured at generation time.
  final Map<String, String> sources;

  /// Duration of the green baseline suite run (ADR 0005).
  final Duration backgroundReading;

  /// Per-mutant timeout derived from the background reading (ADR 0006).
  final Duration halfLife;
}
