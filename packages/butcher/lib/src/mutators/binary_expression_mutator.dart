import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutator.dart';

/// Base for operator-swap mutators on binary expressions.
///
/// Subclasses declare [swaps] as pure data. The default [guard] admits
/// numeric operands only; widening it is an explicit override (ADR 0008).
abstract class BinaryExpressionMutator implements Mutator {
  /// Allows subclasses to have const constructors.
  const BinaryExpressionMutator();

  /// Operator lexeme mapped to its replacement lexemes.
  Map<String, List<String>> get swaps;

  /// Replacement lexemes proposed for [node]; defaults to [swaps].
  List<String> replacementsFor(BinaryExpression node) =>
      swaps[node.operator.lexeme] ?? const [];

  /// Whether [node] is safe to mutate; defaults to numeric operands only.
  bool guard(BinaryExpression node) =>
      _isNumeric(node.leftOperand) && _isNumeric(node.rightOperand);

  /// The mutations this mutator proposes for [node] in [filePath], or none.
  List<Mutation> mutate(BinaryExpression node, String filePath) {
    final operator = node.operator;
    final replacements = replacementsFor(node);
    if (replacements.isEmpty || !guard(node)) return const [];
    return [
      for (final replacement in replacements)
        if (replacement != operator.lexeme)
          Mutation(
            filePath: filePath,
            offset: operator.offset,
            length: operator.length,
            original: operator.lexeme,
            replacement: replacement,
            mutatorId: id,
            description: 'replace ${operator.lexeme} with $replacement',
          ),
    ];
  }

  static bool _isNumeric(Expression operand) {
    final type = operand.staticType;
    if (type == null) return false;
    return type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum;
  }
}
