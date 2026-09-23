import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../model/mutation.dart';
import '../mutators/binary_expression_mutator.dart';
import '../mutators/boolean_literal_mutator.dart';
import '../mutators/mutator_registry.dart';
import '../mutators/null_aware_access_mutator.dart';
import '../mutators/null_coalescing_mutator.dart';
import '../mutators/null_injection_mutator.dart';

/// The single AST walk; dispatches nodes to registered mutators (ADR 0008).
final class MutationVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor collecting into [mutations] for [filePath].
  MutationVisitor({
    required this.registry,
    required this.filePath,
    required this.source,
    required this.mutations,
  });

  /// The active mutator set.
  final MutatorRegistry registry;

  /// Project-relative path of the unit being visited.
  final String filePath;

  /// Full source text of the unit; span mutators slice exact originals.
  final String source;

  /// Collected mutations, in AST visit order (parent before child).
  final List<Mutation> mutations;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    for (final mutator in registry.ofType<BinaryExpressionMutator>()) {
      mutations.addAll(mutator.mutate(node, filePath));
    }
    for (final mutator in registry.ofType<NullCoalescingMutator>()) {
      mutations.addAll(mutator.mutate(node, filePath, source));
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    for (final mutator in registry.ofType<BooleanLiteralMutator>()) {
      mutations.addAll(mutator.mutate(node, filePath));
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
    for (final mutator in registry.ofType<NullAwareAccessMutator>()) {
      mutations.addAll(mutator.mutate(node, filePath));
    }
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    _nullInjection(node);
    super.visitReturnStatement(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _nullInjection(node);
    super.visitExpressionFunctionBody(node);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    _nullInjection(node);
    super.visitArgumentList(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _nullInjection(node);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _nullInjection(node);
    super.visitVariableDeclaration(node);
  }

  void _nullInjection(AstNode node) {
    for (final mutator in registry.ofType<NullInjectionMutator>()) {
      mutations.addAll(mutator.mutate(node, filePath, source));
    }
  }
}
