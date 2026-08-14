import 'mutant.dart';
import 'outcome.dart';

/// The outcome one mutant earned.
class MutantResult {
  const MutantResult({required this.mutant, required this.outcome});

  final Mutant mutant;
  final Outcome outcome;
}
