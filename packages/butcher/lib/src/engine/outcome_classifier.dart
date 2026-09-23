import '../model/outcome.dart';
import '../model/test_events.dart';
import '../model/test_run.dart';

/// Maps one finished test run onto the outcome taxonomy (ADR 0006).
final class OutcomeClassifier {
  /// Creates the classifier; it holds no state.
  const OutcomeClassifier();

  /// The outcome [run] earned for its mutant, [events] being its parsed
  /// stream; the caller parses it, since it also logs its errors.
  Outcome classify(TestRun run, TestEvents events) {
    if (run.timedOut) return Outcome.timeout;
    if (run.exitCode == 0) return Outcome.survived;
    if (events.testFailures.isNotEmpty) return Outcome.killed;
    if (events.loadFailures.isNotEmpty) return Outcome.unviable;
    return Outcome.runError;
  }
}
