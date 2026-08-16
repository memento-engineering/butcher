import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/mutation_visitor.dart';
import 'package:test/test.dart';

Future<List<Mutation>> injectionsOf(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_inject_');
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
      registry: const MutagenRegistry([NullInjectionMutagen()]),
      filePath: 'main.dart',
      source: source,
      mutations: mutations,
    ),
  );
  return mutations;
}

void main() {
  test('injects null into nullable returns, both body forms', () async {
    final mutations = await injectionsOf('''
int? f(int x) => x;
int? g(int x) {
  return x;
}
''');
    expect(mutations, hasLength(2));
    expect(mutations.map((m) => m.original).toSet(), {'x'});
    expect(mutations.map((m) => m.replacement).toSet(), {'null'});
  });

  test('skips non-nullable and inferred returns and closures', () async {
    final mutations = await injectionsOf('''
int f(int x) => x;
List<int?> g(List<int?> xs) => xs.map((x) => x).toList();
''');
    expect(mutations, isEmpty);
  });

  test('injects null into nullable arguments, including named', () async {
    final mutations = await injectionsOf('''
int h(int? a, {int? b}) => (a ?? 0) + (b ?? 0);
int f() => h(1, b: 2);
''');
    expect(mutations.map((m) => m.original), unorderedEquals(['1', '2']));
  });

  test('injects null into nullable assignments and initializers', () async {
    final mutations = await injectionsOf('''
int f(int x) {
  int? held = x;
  held = x + 1;
  return held ?? 0;
}
''');
    expect(mutations.map((m) => m.original), unorderedEquals(['x', 'x + 1']));
  });

  test('skips inferred declarations and existing nulls', () async {
    final mutations = await injectionsOf('''
int? f(int? x) {
  var held = x;
  int? copy = null;
  if (x == null) return null;
  return held ?? copy;
}
''');
    expect(
      mutations.map((m) => m.original),
      ['held ?? copy'],
      reason:
          'inferred declaration, null initializer, and null return '
          'stay untouched; only the nullable return is injected',
    );
  });
}
