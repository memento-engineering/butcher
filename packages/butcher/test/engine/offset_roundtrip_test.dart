import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/containment.dart';
import 'package:butcher/src/engine/mutant_generator.dart';
import 'package:butcher/src/engine/rad_ignore.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

/// Generates on a one-file project, applies every mutant, checks the splice.
Future<void> roundtrip(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_roundtrip_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'lib', 'a.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(source);

  final (mutants, _) = await MutantGenerator(
    projectRoot: dir.path,
    registry: MutagenRegistry.defaults(),
    ignore: RadIgnore.load(dir.path),
  ).generate();
  expect(mutants, isNotEmpty);

  final paths = await isolatedRadPaths('rad_roundtrip_state_');
  final containment = await Containment.create(
    dir.path,
    paths: paths,
    ignore: RadIgnore.load(dir.path),
  );
  final copy = File(p.join(containment.root, 'lib', 'a.dart'));
  for (final mutant in mutants) {
    await containment.apply(mutant.mutation);
    expect(
      copy.readAsStringSync(),
      isNot(source),
      reason: '${mutant.id} must change the copy',
    );
    await containment.restore(mutant.mutation.filePath);
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
