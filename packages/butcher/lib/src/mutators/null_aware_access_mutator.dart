import 'package:analyzer/dart/ast/ast.dart';

import '../model/mutation.dart';
import 'mutator.dart';

/// Replaces `?.` with `!.`: a silent null skip becomes a crash.
///
/// Always compiles: `!` accepts any receiver and the result type only
/// narrows. Cascades (`?..`) and null-aware indexing are follow-ups.
final class NullAwareAccessMutator implements Mutator {
  /// Creates the mutator; it holds no state.
  const NullAwareAccessMutator();

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
        mutatorId: id,
        description: 'replace ?. with !.',
      ),
    ];
  }
}
