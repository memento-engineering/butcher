import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/mutation_visitor.dart';
import 'package:test/test.dart';

Future<List<Mutation>> mutationsOf(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_test_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File(p.join(dir.path, 'main.dart'));
  await file.writeAsString(source);
  final normalized = p.normalize(file.absolute.path);
  final collection = AnalysisContextCollection(includedPaths: [normalized]);
  final result = await collection
      .contextFor(normalized)
      .currentSession
      .getResolvedUnit(normalized);
  final mutations = <Mutation>[];
  (result as ResolvedUnitResult).unit.accept(
    MutationVisitor(
      registry: MutagenRegistry.defaults(),
      filePath: 'main.dart',
      source: source,
      mutations: mutations,
    ),
  );
  return mutations;
}

void main() {
  test('mutates int arithmetic with every declared swap', () async {
    final mutations = await mutationsOf('int f(int a, int b) => a + b;');
    final swaps = mutations.where((m) => m.operatorId == 'arithmetic').toList();
    expect(swaps.map((m) => m.original).toSet(), {'+'});
    expect(swaps.map((m) => m.replacement), unorderedEquals(['-', '*']));
    expect(swaps.map((m) => m.length).toSet(), {1});
  });

  test('swaps int multiplication to truncating division', () async {
    final mutations = await mutationsOf('int f(int a, int b) => a * b;');
    final swaps = mutations.where((m) => m.operatorId == 'arithmetic');
    expect(swaps.map((m) => m.replacement), unorderedEquals(['/', '~/', '+']));
  });

  test('swaps double remainder to floating division', () async {
    final mutations = await mutationsOf(
      'double f(double a, double b) => a % b;',
    );
    final swaps = mutations.where((m) => m.operatorId == 'arithmetic');
    expect(swaps.map((m) => m.replacement), unorderedEquals(['*', '/']));
  });

  test('keeps the declared swap when the result type is num', () async {
    final mutations = await mutationsOf('num f(num a, num b) => a * b;');
    final swaps = mutations.where((m) => m.operatorId == 'arithmetic');
    expect(swaps.map((m) => m.replacement), unorderedEquals(['/', '+']));
  });

  test('keeps floating division valid in a wider num context', () async {
    final mutations = await mutationsOf('num f(int a, int b) => a * b;');
    final swaps = mutations.where((m) => m.operatorId == 'arithmetic');
    expect(swaps.map((m) => m.replacement), unorderedEquals(['/', '~/', '+']));
  });

  test('guards string concatenation from arithmetic swaps', () async {
    final mutations = await mutationsOf("String f(String s) => 'a' + s;");
    expect(mutations.where((m) => m.operatorId == 'arithmetic'), isEmpty);
  });

  test('mutates equality on any operand types', () async {
    final mutations = await mutationsOf("bool f(String s) => s == 'x';");
    final swap = mutations.singleWhere((m) => m.operatorId == 'equality');
    expect(swap.replacement, '!=');
  });

  test('mutates logical operators', () async {
    final mutations = await mutationsOf('bool f(bool a, bool b) => a && b;');
    final swap = mutations.singleWhere((m) => m.operatorId == 'logical');
    expect(swap.replacement, '||');
  });

  test('mutates relational operators on numbers only', () async {
    final mutations = await mutationsOf('''
class Probe {
  bool operator <(Probe other) => true;
}
bool f(Probe a, Probe b, int x, int y) => a < b && x < y;
''');
    final swaps = mutations.where((m) => m.operatorId == 'relational');
    expect(swaps.map((m) => m.replacement), unorderedEquals(['<=', '>=']));
  });

  test('flips boolean literals', () async {
    final mutations = await mutationsOf('bool f() => true;');
    final swap = mutations.singleWhere((m) => m.operatorId == 'bool-literal');
    expect(swap.original, 'true');
    expect(swap.replacement, 'false');
  });

  test('enumeration is deterministic', () async {
    const source = 'int f(int a, int b) => a * b + a % b;';
    final first = await mutationsOf(source);
    final second = await mutationsOf(source);
    expect(
      first.map((m) => '${m.offset}:${m.operatorId}:${m.replacement}'),
      second.map((m) => '${m.offset}:${m.operatorId}:${m.replacement}'),
    );
  });
}
