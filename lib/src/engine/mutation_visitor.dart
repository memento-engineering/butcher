import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../model/mutation.dart';
import '../mutagens/binary_expression_mutagen.dart';
import '../mutagens/boolean_literal_mutagen.dart';
import '../mutagens/mutagen_registry.dart';
import '../mutagens/null_aware_access_mutagen.dart';
import '../mutagens/null_coalescing_mutagen.dart';

/// The single AST walk; dispatches nodes to registered mutagens (ADR 0008).
final class MutationVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor collecting into [mutations] for [filePath].
  MutationVisitor({
    required this.registry,
    required this.filePath,
    required this.source,
    required this.mutations,
  });

  /// The active mutagen set.
  final MutagenRegistry registry;

  /// Project-relative path of the unit being visited.
  final String filePath;

  /// Full source text of the unit; span mutagens slice exact originals.
  final String source;

  /// Collected mutations, in AST visit order (parent before child).
  final List<Mutation> mutations;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    for (final mutagen in registry.ofType<BinaryExpressionMutagen>()) {
      mutations.addAll(mutagen.mutate(node, filePath));
    }
    for (final mutagen in registry.ofType<NullCoalescingMutagen>()) {
      mutations.addAll(mutagen.mutate(node, filePath, source));
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

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _nullAware(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _nullAware(node);
    super.visitPropertyAccess(node);
  }

  void _nullAware(Expression node) {
    for (final mutagen in registry.ofType<NullAwareAccessMutagen>()) {
      mutations.addAll(mutagen.mutate(node, filePath));
    }
  }
}
