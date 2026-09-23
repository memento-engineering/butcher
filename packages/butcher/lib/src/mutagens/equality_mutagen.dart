import 'package:analyzer/dart/ast/ast.dart';

import 'binary_expression_mutagen.dart';
import 'promotion_dependence.dart';

/// Swaps `==` with `!=` and back on any operands.
///
/// The counterpart is the only equality operator, so each site has one swap.
/// Widened guard: any operand types compile, except null tests whose flip
/// strands a promoted use; the viability check backstops the remainder
/// (ADR 0019).
final class EqualityMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const EqualityMutagen();

  @override
  String get id => 'equality';

  @override
  Map<String, List<String>> get swaps => const {
    '==': ['!='],
    '!=': ['=='],
  };

  @override
  bool guard(BinaryExpression node) => !PromotionDependence.flipStrands(node);
}
