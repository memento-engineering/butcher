import 'binary_expression_mutagen.dart';

/// Swaps relational operators on numeric operands.
///
/// Each operator maps to its boundary neighbor and its negation.
final class RelationalMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const RelationalMutagen();

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
