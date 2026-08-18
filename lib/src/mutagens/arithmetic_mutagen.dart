import 'package:analyzer/dart/ast/ast.dart';

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

  /// Picks the division flavour whose result still fits the slot the
  /// original expression filled: `/` always yields `double` and `~/` always
  /// yields `int`, so the wrong one cannot compile and would only burn a
  /// viability analysis (ADR 0019). Unresolved or `num`-typed expressions
  /// keep the declared swap and let the viability check decide.
  @override
  List<String> replacementsFor(BinaryExpression node) {
    final type = node.staticType;
    final division = type == null
        ? null
        : type.isDartCoreInt
        ? '~/'
        : type.isDartCoreDouble
        ? '/'
        : null;
    final declared = super.replacementsFor(node);
    if (division == null) return declared;
    return [
      for (final replacement in declared)
        replacement == '/' || replacement == '~/' ? division : replacement,
    ];
  }
}
