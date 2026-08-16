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
  /// null/is tests — strands a use needing the promoted type inside the
  /// flipped test's promotion scope.
  static bool flipStrands(BinaryExpression node) {
    switch (node.operator.lexeme) {
      case '==' || '!=':
        final variable = _nullTestedVariable(node);
        if (variable == null) return false;
        return _strands({
          variable,
        }, _promotionScope(node, node.operator.lexeme == '!='));
      case '&&' || '||':
        if (_strands(_testsIn(node.leftOperand), [node.rightOperand])) {
          return true;
        }
        return _strands(
          _testsIn(node),
          _promotionScope(node, node.operator.lexeme == '&&'),
        );
      default:
        return false;
    }
  }

  static bool _strands(Set<Element> tested, List<AstNode> regions) {
    if (tested.isEmpty) return false;
    final finder = _DependingUseFinder(tested);
    for (final region in regions) {
      region.accept(finder);
      if (finder.found) return true;
    }
    return false;
  }

  /// The regions where the promotion from [test] holds, given it promotes
  /// when the test evaluates to [promoted]. Unclear contexts end the walk:
  /// missed regions keep the mutant for the viability filter.
  static List<AstNode> _promotionScope(Expression test, bool promoted) {
    final regions = <AstNode>[];
    var expression = test;
    while (true) {
      final parent = expression.parent;
      switch (parent) {
        case ParenthesizedExpression():
          expression = parent;
        case PrefixExpression() when parent.operator.type == TokenType.BANG:
          promoted = !promoted;
          expression = parent;
        case BinaryExpression(:final operator)
            when operator.lexeme == '&&' || operator.lexeme == '||':
          if (promoted != (operator.lexeme == '&&')) return regions;
          if (identical(parent.leftOperand, expression)) {
            regions.add(parent.rightOperand);
          }
          expression = parent;
        case ConditionalExpression()
            when identical(parent.condition, expression):
          regions.add(promoted ? parent.thenExpression : parent.elseExpression);
          return regions;
        case IfStatement() when identical(parent.expression, expression):
          final branch = promoted ? parent.thenStatement : parent.elseStatement;
          if (branch != null) regions.add(branch);
          final exiting = promoted
              ? parent.elseStatement
              : parent.thenStatement;
          if (exiting != null && _exits(exiting)) {
            regions.addAll(_followingStatements(parent));
          }
          return regions;
        case WhileStatement() when identical(parent.condition, expression):
          if (promoted) regions.add(parent.body);
          return regions;
        default:
          return regions;
      }
    }
  }

  static bool _exits(Statement statement) => switch (statement) {
    Block(:final statements) =>
      statements.isNotEmpty && _exits(statements.last),
    ReturnStatement() => true,
    BreakStatement() => true,
    ContinueStatement() => true,
    ExpressionStatement(:final expression) =>
      expression is ThrowExpression || expression is RethrowExpression,
    _ => false,
  };

  static Iterable<Statement> _followingStatements(Statement statement) {
    final block = statement.parent;
    if (block is! Block) return const [];
    final statements = block.statements;
    return statements.skip(statements.indexOf(statement) + 1);
  }

  /// Promotable variables null- or is-tested within [expression].
  static Set<Element> _testsIn(Expression expression) {
    final collector = _TestCollector();
    expression.accept(collector);
    return collector.tested;
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
