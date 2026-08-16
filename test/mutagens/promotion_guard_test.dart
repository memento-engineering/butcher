import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/mutation_visitor.dart';
import 'package:test/test.dart';

Future<List<Mutation>> mutationsOf(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_guard_');
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

Iterable<Mutation> ofOperator(List<Mutation> mutations, String id) =>
    mutations.where((m) => m.operatorId == id);

void main() {
  test('skips null-test flips stranding a member access', () async {
    final mutations = await mutationsOf('''
int f(String? s) {
  if (s == null) return 0;
  return s.length;
}
''');
    expect(ofOperator(mutations, 'equality'), isEmpty);
  });

  test('skips null-test flips stranding an argument', () async {
    final mutations = await mutationsOf('''
int g(String s) => s.length;
int f(String? s) {
  if (s == null) return 0;
  return g(s);
}
''');
    expect(ofOperator(mutations, 'equality'), isEmpty);
  });

  test('keeps null-test flips no downstream use depends on', () async {
    final mutations = await mutationsOf('''
String f(int? level) => level == null ? 'INF' : 'ERR';
''');
    expect(ofOperator(mutations, 'equality'), hasLength(1));
  });

  test('keeps null-test flips over promotion-agnostic uses', () async {
    final mutations = await mutationsOf('''
String f(int? count) {
  if (count == null) return '';
  return 'total: \$count';
}
''');
    expect(ofOperator(mutations, 'equality'), hasLength(1));
  });

  test('skips logical flips stranding the guarded operand', () async {
    final mutations = await mutationsOf('''
bool f(int? threshold) => threshold != null && threshold < 5;
''');
    expect(ofOperator(mutations, 'logical'), isEmpty);
    expect(
      ofOperator(mutations, 'equality'),
      isEmpty,
      reason: 'the null test itself also guards the relational use',
    );
  });

  test('skips logical flips around is tests', () async {
    final mutations = await mutationsOf('''
bool f(Object o) => o is String && o.isNotEmpty;
''');
    expect(ofOperator(mutations, 'logical'), isEmpty);
  });

  test('keeps logical flips with independent operands', () async {
    final mutations = await mutationsOf('''
bool f(int? x, bool ansi) => x == null && ansi;
''');
    expect(ofOperator(mutations, 'logical'), hasLength(1));
  });

  test('keeps null-test flips outside the depending use\'s guard', () async {
    final mutations = await mutationsOf('''
int f(String? s) {
  final missing = s == null;
  if (s == null) return 0;
  return missing ? 1 : s.length;
}
''');
    expect(
      ofOperator(mutations, 'equality'),
      hasLength(1),
      reason: 'the initializer test promotes nothing the second test guards',
    );
  });

  test('skips null-test flips stranding a branch use', () async {
    final mutations = await mutationsOf('''
int f(String? s) {
  if (s != null) return s.length;
  return 0;
}
''');
    expect(ofOperator(mutations, 'equality'), isEmpty);
  });

  test(
    'keeps logical flips whose promotion stays in the left operand',
    () async {
      final mutations = await mutationsOf('''
bool f(String? s, bool t) => (s != null && s.isNotEmpty) || t;
''');
      expect(
        ofOperator(mutations, 'logical'),
        hasLength(1),
        reason: 'flipping the || leaves the inner && promotion intact',
      );
    },
  );

  test('keeps equality flips on non-null operands', () async {
    final mutations = await mutationsOf('''
bool f(String s) => s == 'x' && s.isNotEmpty;
''');
    expect(ofOperator(mutations, 'equality'), hasLength(1));
  });
}
