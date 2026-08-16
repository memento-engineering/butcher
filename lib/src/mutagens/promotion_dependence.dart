import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Predicts operator flips that break flow-based type promotion, by reading
/// promotion facts off the resolved AST instead of re-running flow analysis.
///
/// Only clear-cut contexts count as depending on a promotion: uncertain
/// sites keep their mutants and the viability filter backstops them
/// (ADR 0019). Guards minimize unviable mutants; the filter eliminates them.
final class PromotionDependence {
  const PromotionDependence._();

  /// Members every nullable type still exposes.
  static const _objectMembers = {
    'toString',
    'hashCode',
    'runtimeType',
    'noSuchMethod',
  };

  /// Whether flipping [node] — a null test, or a logical operator around
  /// null/is tests — strands a use needing the promoted type in the
  /// enclosing scope.
  static bool flipStrands(BinaryExpression node) {
    final tested = _testedVariables(node);
    if (tested.isEmpty) return false;
    final scope =
        node.thisOrAncestorOfType<FunctionBody>() ??
        node.thisOrAncestorOfType<Declaration>() as AstNode?;
    if (scope == null) return false;
    final finder = _DependingUseFinder(tested);
    scope.accept(finder);
    return finder.found;
  }

  /// The promotable variables whose tests the flip of [node] disturbs.
  static Set<Element> _testedVariables(BinaryExpression node) {
    switch (node.operator.lexeme) {
      case '==' || '!=':
        return {?_nullTestedVariable(node)};
      case '&&' || '||':
        final collector = _TestCollector();
        node.accept(collector);
        return collector.tested;
      default:
        return const {};
    }
  }

  static Element? _nullTestedVariable(BinaryExpression node) {
    if (node.rightOperand is NullLiteral) return _promotable(node.leftOperand);
    if (node.leftOperand is NullLiteral) return _promotable(node.rightOperand);
    return null;
  }

  /// Locals and parameters promote; anything else does not (or only under
  /// rules not worth modeling here).
  static Element? _promotable(Expression expression) {
    if (expression is! SimpleIdentifier) return null;
    final element = expression.element;
    if (element is LocalVariableElement || element is FormalParameterElement) {
      return element;
    }
    return null;
  }

  /// Whether [use] only compiles with the promoted (non-nullable) type.
  static bool _depends(SimpleIdentifier use) {
    final parent = use.parent;
    if (parent is PrefixedIdentifier && identical(parent.prefix, use)) {
      return !_objectMembers.contains(parent.identifier.name);
    }
    if (parent is PropertyAccess &&
        identical(parent.target, use) &&
        parent.operator.type == TokenType.PERIOD) {
      return !_objectMembers.contains(parent.propertyName.name);
    }
    if (parent is MethodInvocation &&
        identical(parent.target, use) &&
        parent.operator?.type == TokenType.PERIOD) {
      return !_objectMembers.contains(parent.methodName.name);
    }
    if (parent is BinaryExpression) {
      final operator = parent.operator.lexeme;
      return operator != '==' && operator != '!=' && operator != '??';
    }
    final parameter = use.correspondingParameter;
    if (parameter == null) return false;
    final type = parameter.type;
    return type.nullabilitySuffix == NullabilitySuffix.none &&
        type is! DynamicType &&
        type is! TypeParameterType;
  }
}

/// Collects promotable variables null- or is-tested within a subtree.
final class _TestCollector extends RecursiveAstVisitor<void> {
  final Set<Element> tested = {};

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.lexeme;
    if (operator == '==' || operator == '!=') {
      final variable = PromotionDependence._nullTestedVariable(node);
      if (variable != null) tested.add(variable);
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    final variable = PromotionDependence._promotable(node.expression);
    if (variable != null) tested.add(variable);
    super.visitIsExpression(node);
  }
}

/// Finds a use of any [targets] variable that depends on its promotion.
final class _DependingUseFinder extends RecursiveAstVisitor<void> {
  _DependingUseFinder(this.targets);

  final Set<Element> targets;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!found &&
        targets.contains(node.element) &&
        PromotionDependence._depends(node)) {
      found = true;
    }
  }
}
