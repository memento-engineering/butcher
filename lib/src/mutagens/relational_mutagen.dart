import 'binary_expression_mutagen.dart';

/// Swaps relational operators on numeric operands.
///
/// Each operator maps to its boundary-breaking negation so one swap per site
/// keeps mutant ids unique (ADR 0007).
final class RelationalMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const RelationalMutagen();

  @override
  String get id => 'relational';

  @override
  Map<String, String> get swaps => const {
    '<': '>=',
    '<=': '>',
    '>': '<=',
    '>=': '<',
  };
}
