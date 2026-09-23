import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:butcher/src/mutagens/binary_expression_mutagen.dart';
import 'package:test/test.dart';

final class SelfSwapMutagen extends BinaryExpressionMutagen {
  const SelfSwapMutagen();

  @override
  String get id => 'self-swap';

  @override
  Map<String, List<String>> get swaps => const {
    '+': ['+', '-'],
  };
}

Future<BinaryExpression> binaryOf(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_binary_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString(source);
  final path = p.normalize(file.absolute.path);
  final result = await AnalysisContextCollection(
    includedPaths: [path],
  ).contextFor(path).currentSession.getResolvedUnit(path) as ResolvedUnitResult;
  final function = result.unit.declarations.single as FunctionDeclaration;
  final body = function.functionExpression.body as ExpressionFunctionBody;
  return body.expression as BinaryExpression;
}

void main() {
  test('never proposes the operator it replaces', () async {
    final node = await binaryOf('int f(int a, int b) => a + b;');
    final mutations = const SelfSwapMutagen().mutate(node, 'main.dart');
    expect(mutations.map((mutation) => mutation.replacement), ['-']);
  });
}
