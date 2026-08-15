import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutagen.dart';

/// Flips `true` to `false` and back.
final class BooleanLiteralMutagen implements Mutagen {
  /// Creates the mutagen; it holds no state.
  const BooleanLiteralMutagen();

  @override
  String get id => 'bool-literal';

  /// The mutations this mutagen proposes for [node] in [filePath].
  List<Mutation> mutate(BooleanLiteral node, String filePath) {
    final replacement = (!node.value).toString();
    return [
      Mutation(
        filePath: filePath,
        offset: node.offset,
        length: node.length,
        original: node.literal.lexeme,
        replacement: replacement,
        operatorId: id,
        description: 'replace ${node.literal.lexeme} with $replacement',
      ),
    ];
  }
}
