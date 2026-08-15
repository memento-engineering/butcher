import '../model/outcome.dart';
import 'test_run.dart';

/// Marker `dart test` prints when a suite fails to compile or load.
const _loadFailureMarker = 'Failed to load';

/// Maps one finished test run onto the outcome taxonomy (ADR 0006).
final class OutcomeClassifier {
  /// Creates the classifier; it holds no state.
  const OutcomeClassifier();

  /// The outcome [run] earned for its mutant.
  Outcome classify(TestRun run) {
    if (run.timedOut) return Outcome.timeout;
    if (run.exitCode == 0) return Outcome.survived;
    if (run.exitCode == 1) {
      return run.output.contains(_loadFailureMarker)
          ? Outcome.unviable
          : Outcome.killed;
    }
    return Outcome.runError;
  }
}
