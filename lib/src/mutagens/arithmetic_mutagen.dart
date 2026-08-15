import 'binary_expression_mutagen.dart';

/// Swaps arithmetic operators on numeric operands.
final class ArithmeticMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const ArithmeticMutagen();

  @override
  String get id => 'arithmetic';

  @override
  Map<String, List<String>> get swaps => const {
    '+': ['-', '*'],
    '-': ['+', '*'],
    '*': ['/', '+'],
    '/': ['*', '-'],
    '%': ['*', '~/'],
    '~/': ['*', '%'],
  };
}
