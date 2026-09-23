import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/sandbox.dart';
import 'package:butcher/src/engine/mutant_generator.dart';
import 'package:butcher/src/config/mutation_scope.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

/// Generates on a one-file project, applies every mutant, checks the splice.
Future<void> roundtrip(String source) async {
  final dir = await Directory.systemTemp.createTemp('butcher_roundtrip_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'lib', 'a.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(source);
  await initGitRepository(dir.path);

  final (mutants, _) = await MutantGenerator(
    projectRoot: dir.path,
    registry: MutatorRegistry.defaults(),
    isExcluded: MutationScope.load(dir.path).excludes,
  ).generate();
  expect(mutants, isNotEmpty);

  final paths = await isolatedButcherPaths('butcher_roundtrip_state_');
  final sandbox = await Sandbox.create(dir.path, paths: paths);
  final copy = File(p.join(sandbox.root, 'lib', 'a.dart'));
  for (final mutant in mutants) {
    await sandbox.apply(mutant.mutation);
    expect(
      copy.readAsStringSync(),
      isNot(source),
      reason: '${mutant.id} must change the copy',
    );
    await sandbox.restore(mutant.mutation.filePath);
    expect(
      copy.readAsStringSync(),
      source,
      reason: '${mutant.id} must restore cleanly',
    );
  }
}

void main() {
  test('offsets stay aligned in CRLF sources', () async {
    await roundtrip('int f(int a) {\r\n  return a + 1;\r\n}\r\n');
  });

  test('offsets stay aligned after non-ASCII text', () async {
    await roundtrip(
      "const grüße = 'ünïcode \u{1F600}';\nint f(int a) => a + 1;\n",
    );
  });

  test('offsets stay aligned across many mutants in one file', () async {
    await roundtrip(
      'bool f(int a, int b) => a + b > 0 && a * b != 0 || a == b;\n',
    );
  });
}
