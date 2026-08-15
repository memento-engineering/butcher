import 'package:analyzer/dart/ast/ast.dart';

import 'binary_expression_mutagen.dart';

/// Swaps `&&` with `||` and back.
///
/// Widened guard: logical operands are `bool` by language rules.
final class LogicalMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const LogicalMutagen();

  @override
  String get id => 'logical';

  @override
  Map<String, String> get swaps => const {'&&': '||', '||': '&&'};

  @override
  bool guard(BinaryExpression node) => true;
}
