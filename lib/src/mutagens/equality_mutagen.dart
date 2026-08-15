import 'package:analyzer/dart/ast/ast.dart';

import 'binary_expression_mutagen.dart';

/// Swaps `==` with `!=` and back on any operands.
///
/// Widened guard: equality always yields `bool`, so every site compiles.
final class EqualityMutagen extends BinaryExpressionMutagen {
  /// Creates the mutagen; it holds no state.
  const EqualityMutagen();

  @override
  String get id => 'equality';

  @override
  Map<String, String> get swaps => const {'==': '!=', '!=': '=='};

  @override
  bool guard(BinaryExpression node) => true;
}
