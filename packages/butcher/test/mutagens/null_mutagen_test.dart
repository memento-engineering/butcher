import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/mutation_visitor.dart';
import 'package:test/test.dart';

Future<List<Mutation>> mutationsOf(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_null_');
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
  test('mutates ?? into always and never falling back', () async {
    final mutations = await mutationsOf('int f(int? a, int b) => a ?? b;');
    final swaps = mutations
        .where((m) => m.operatorId == 'null-coalescing')
        .toList();
    expect(swaps.map((m) => m.original).toSet(), {'a ?? b'});
    expect(swaps.map((m) => m.replacement), unorderedEquals(['b', 'a!']));
  });

  test('parenthesizes low-precedence left operands before !', () async {
    final mutations = await mutationsOf(
      'Future<int> f(Future<int?> g, int b) async => await g ?? b;',
    );
    final swaps = mutations.where((m) => m.operatorId == 'null-coalescing');
    expect(
      swaps.map((m) => m.replacement),
      unorderedEquals(['b', '(await g)!']),
    );
  });

  test('parenthesizes null-shorted chains before !', () async {
    final mutations = await mutationsOf('int f(String? s) => s?.length ?? 0;');
    final swaps = mutations.where((m) => m.operatorId == 'null-coalescing');
    expect(
      swaps.map((m) => m.replacement),
      unorderedEquals(['0', '(s?.length)!']),
      reason: 's?.length! would stay nullable through null shorting',
    );
  });

  test('replaces ?. with !. on property access and invocation', () async {
    final mutations = await mutationsOf('''
int f(String? s) => s?.length ?? 0;
String? g(String? s) => s?.trim();
''');
    final swaps = mutations.where((m) => m.operatorId == 'null-aware');
    expect(swaps, hasLength(2));
    expect(swaps.map((m) => m.original).toSet(), {'?.'});
    expect(swaps.map((m) => m.replacement).toSet(), {'!.'});
  });

  test('leaves plain access and non-?? operators alone', () async {
    final mutations = await mutationsOf('int f(String s) => s.length;');
    expect(
      mutations.where(
        (m) => const {'null-aware', 'null-coalescing'}.contains(m.operatorId),
      ),
      isEmpty,
    );
  });
}
