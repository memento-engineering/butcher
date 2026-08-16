import 'mutant.dart';
import 'outcome.dart';
import 'test_run.dart';

/// The outcome one mutant earned.
class MutantResult {
  /// Creates a result pairing [mutant] with its [outcome].
  const MutantResult({
    required this.mutant,
    required this.outcome,
    this.testRun,
    this.error,
  });

  /// The mutant that was put under test.
  final Mutant mutant;

  /// The category this mutant's run ended in.
  final Outcome outcome;

  /// The test run that produced [outcome]; `null` when no tests ran.
  final TestRun? testRun;

  /// Exception and stack trace behind a [Outcome.runError] without [testRun].
  final String? error;
}
