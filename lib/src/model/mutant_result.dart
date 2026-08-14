import 'mutant.dart';
import 'outcome.dart';

/// The outcome one mutant earned.
class MutantResult {
  /// Creates a result pairing [mutant] with its [outcome].
  const MutantResult({required this.mutant, required this.outcome});

  /// The mutant that was put under test.
  final Mutant mutant;

  /// The category this mutant's run ended in.
  final Outcome outcome;
}
