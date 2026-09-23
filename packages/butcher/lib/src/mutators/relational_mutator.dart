import 'binary_expression_mutator.dart';

/// Swaps relational operators on numeric operands.
///
/// Each operator maps to its boundary neighbor and its negation.
final class RelationalMutator extends BinaryExpressionMutator {
  /// Creates the mutator; it holds no state.
  const RelationalMutator();

  @override
  String get id => 'relational';

  @override
  Map<String, List<String>> get swaps => const {
    '<': ['<=', '>='],
    '<=': ['<', '>'],
    '>': ['>=', '<='],
    '>=': ['>', '<'],
  };
}
