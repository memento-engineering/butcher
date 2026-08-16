import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../model/mutation.dart';
import 'mutagen.dart';

/// Injects `null` into slots whose declared context type is nullable:
/// returns, arguments, assignments, and explicitly typed initializers.
///
/// Sound null safety forbids `null` in non-nullable slots outright, so only
/// declared-nullable contexts are mutable; there the injection compiles by
/// construction and asks whether downstream code truly handles null.
final class NullInjectionMutagen implements Mutagen {
  /// Creates the mutagen; it holds no state.
  const NullInjectionMutagen();

  @override
  String get id => 'null-injection';

  /// The mutations for [node] in [filePath]; [source] is the unit's text.
  List<Mutation> mutate(AstNode node, String filePath, String source) {
    final expressions = switch (node) {
      ReturnStatement(:final expression?)
          when _nullableAnnotation(_declaredReturnType(node)) =>
        [expression],
      ExpressionFunctionBody(:final expression, :final parent?)
          when _nullableAnnotation(_returnTypeOf(parent)) =>
        [expression],
      ArgumentList() => [
        for (final argument in node.arguments)
          if (_nullableParameter(argument)) argument.argumentExpression,
      ],
      AssignmentExpression(:final rightHandSide, :final writeType?)
          when node.operator.type == TokenType.EQ && _nullable(writeType) =>
        [rightHandSide],
      VariableDeclaration(
        :final initializer?,
        parent: VariableDeclarationList(:final type?),
      )
          when _nullableAnnotation(type) =>
        [initializer],
      _ => const <Expression>[],
    };
    return [
      for (final expression in expressions)
        if (expression is! NullLiteral)
          Mutation(
            filePath: filePath,
            offset: expression.offset,
            length: expression.length,
            original: source.substring(expression.offset, expression.end),
            replacement: 'null',
            operatorId: id,
            description: 'inject null',
          ),
    ];
  }

  /// The declared return type governing [node], or null when inferred or
  /// inside a closure.
  static TypeAnnotation? _declaredReturnType(ReturnStatement node) {
    final owner = node.thisOrAncestorOfType<FunctionBody>()?.parent;
    return owner == null ? null : _returnTypeOf(owner);
  }

  static TypeAnnotation? _returnTypeOf(AstNode owner) => switch (owner) {
    MethodDeclaration(:final returnType) => returnType,
    FunctionExpression(parent: FunctionDeclaration(:final returnType)) =>
      returnType,
    _ => null,
  };

  static bool _nullableParameter(Argument argument) {
    final parameter = argument.correspondingParameter;
    if (parameter == null) return false;
    return _nullable(parameter.type);
  }

  /// Type parameters stay out: `null` would distort generic inference.
  static bool _nullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question &&
      type is! TypeParameterType;

  static bool _nullableAnnotation(TypeAnnotation? annotation) {
    final type = annotation?.type;
    return type != null && _nullable(type);
  }
}
