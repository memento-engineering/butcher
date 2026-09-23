import 'package:analyzer/dart/ast/ast.dart';

import 'binary_expression_mutator.dart';

/// Swaps arithmetic operators on numeric operands.
final class ArithmeticMutator extends BinaryExpressionMutator {
  /// Creates the mutator; it holds no state.
  const ArithmeticMutator();

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

  /// Adds truncating division when an integer expression may require it.
  ///
  /// The expression's own type does not reveal a wider contextual slot, so
  /// the declared `/` swap stays: viability filtering rejects it where the
  /// surrounding context truly requires `int` (ADR 0019).
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
    if (division == '~/') {
      return [
        for (final replacement in declared) replacement,
        if (declared.any((replacement) => replacement == '/')) division,
      ];
    }
    return [
      for (final replacement in declared)
        replacement == '~/' ? division : replacement,
    ];
  }
}
