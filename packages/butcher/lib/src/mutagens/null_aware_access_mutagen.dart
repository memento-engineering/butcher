import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutagen.dart';

/// Replaces `?.` with `!.`: a silent null skip becomes a crash.
///
/// Always compiles: `!` accepts any receiver and the result type only
/// narrows. Cascades (`?..`) and null-aware indexing are follow-ups.
final class NullAwareAccessMutagen implements Mutagen {
  /// Creates the mutagen; it holds no state.
  const NullAwareAccessMutagen();

  @override
  String get id => 'null-aware';

  /// The mutations for [node] in [filePath], when it accesses via `?.`.
  List<Mutation> mutate(Expression node, String filePath) {
    final operator = switch (node) {
      PropertyAccess(:final operator) => operator,
      MethodInvocation(:final operator?) => operator,
      _ => null,
    };
    if (operator == null || operator.lexeme != '?.') return const [];
    return [
      Mutation(
        filePath: filePath,
        offset: operator.offset,
        length: operator.length,
        original: operator.lexeme,
        replacement: '!.',
        operatorId: id,
        description: 'replace ?. with !.',
      ),
    ];
  }
}
