import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutagen.dart';

/// Mutates `a ?? b` into always (`b`) and never (`a!`) falling back.
///
/// Both forms compile by construction: the fallback was already checked
/// against the same context, and `a!` only narrows a nullable type.
final class NullCoalescingMutagen implements Mutagen {
  /// Creates the mutagen; it holds no state.
  const NullCoalescingMutagen();

  @override
  String get id => 'null-coalescing';

  /// The mutations for [node] in [filePath]; [source] is the unit's text.
  List<Mutation> mutate(BinaryExpression node, String filePath, String source) {
    if (node.operator.lexeme != '??') return const [];
    final left = node.leftOperand;
    final leftSource = source.substring(left.offset, left.end);
    final bang = _bangSafe(left) ? '$leftSource!' : '($leftSource)!';
    final fallback = source.substring(
      node.rightOperand.offset,
      node.rightOperand.end,
    );
    return [
      for (final replacement in [fallback, bang])
        Mutation(
          filePath: filePath,
          offset: node.offset,
          length: node.length,
          original: source.substring(node.offset, node.end),
          replacement: replacement,
          operatorId: id,
          description:
              'replace ${node.operator.lexeme} expression '
              'with $replacement',
        ),
    ];
  }

  /// Whether `!` may be appended without parentheses. Anything more complex
  /// gets parenthesized: precedence aside, `!` inside a null-shorted chain
  /// (`a?.b!`) would keep the chain nullable instead of narrowing it.
  static bool _bangSafe(Expression left) =>
      left is SimpleIdentifier ||
      left is PrefixedIdentifier ||
      left is Literal ||
      left is ThisExpression ||
      left is ParenthesizedExpression;
}
