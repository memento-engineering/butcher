import 'package:analyzer/dart/ast/ast.dart';

import 'binary_expression_mutagen.dart';
import 'promotion_dependence.dart';

/// Swaps `&&` with `||` and back.
///
/// The counterpart is the only short-circuit peer, so each site has one swap.
/// Widened guard: operands are `bool` by language rules, but flips that
/// strand a promoted use are skipped; the viability check backstops the
/// remainder (ADR 0019).
final class LogicalMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const LogicalMutagen();

  @override
  String get id => 'logical';

  @override
  Map<String, List<String>> get swaps => const {
    '&&': ['||'],
    '||': ['&&'],
  };

  @override
  bool guard(BinaryExpression node) => !PromotionDependence.flipStrands(node);
}
