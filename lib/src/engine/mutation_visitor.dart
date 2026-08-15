import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../model/mutation.dart';
import '../mutagens/binary_expression_mutagen.dart';
import '../mutagens/boolean_literal_mutagen.dart';
import '../mutagens/mutagen_registry.dart';

/// The single AST walk; dispatches nodes to registered mutagens (ADR 0008).
final class MutationVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor collecting into [mutations] for [filePath].
  MutationVisitor({
    required this.registry,
    required this.filePath,
    required this.mutations,
  });

  /// The active mutagen set.
  final MutagenRegistry registry;

  /// Project-relative path of the unit being visited.
  final String filePath;

  /// Collected mutations, in AST visit order (parent before child).
  final List<Mutation> mutations;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    for (final mutagen in registry.ofType<BinaryExpressionMutagen>()) {
      mutations.addAll(mutagen.mutate(node, filePath));
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    for (final mutagen in registry.ofType<BooleanLiteralMutagen>()) {
      mutations.addAll(mutagen.mutate(node, filePath));
    }
    super.visitBooleanLiteral(node);
  }
}
