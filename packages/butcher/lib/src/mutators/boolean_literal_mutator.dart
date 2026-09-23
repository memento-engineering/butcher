import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutator.dart';

/// Flips `true` to `false` and back.
final class BooleanLiteralMutator implements Mutator {
  /// Creates the mutator; it holds no state.
  const BooleanLiteralMutator();

  @override
  String get id => 'bool-literal';

  /// The mutations this mutator proposes for [node] in [filePath].
  List<Mutation> mutate(BooleanLiteral node, String filePath) {
    final replacement = (!node.value).toString();
    return [
      Mutation(
        filePath: filePath,
        offset: node.offset,
        length: node.length,
        original: node.literal.lexeme,
        replacement: replacement,
        mutatorId: id,
        description: 'replace ${node.literal.lexeme} with $replacement',
      ),
    ];
  }
}
