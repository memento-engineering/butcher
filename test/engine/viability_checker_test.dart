import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/viability_checker.dart';
import 'package:test/test.dart';

const _guarded = '''
int? parse(String? raw) {
  if (raw == null) return null;
  return int.parse(raw);
}
''';

const _unguarded = '''
String label(int? level) => level == null ? 'INF' : 'ERR';
''';

Future<String> fixtureProject(String source) async {
  final dir = await Directory.systemTemp.createTemp('rad_viability_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'pubspec.yaml'))
      .writeAsStringSync('name: fixture\nenvironment:\n  sdk: ^3.0.0\n');
  File(p.join(dir.path, 'lib', 'a.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(source);
  return dir.path;
}

Mutation flipAt(String source, String original, String replacement) => Mutation(
  filePath: 'lib/a.dart',
  offset: source.indexOf(original),
  length: original.length,
  original: original,
  replacement: replacement,
  operatorId: 'equality',
  description: 'replace $original with $replacement',
);

void main() {
  test('rejects a flip that breaks null promotion downstream', () async {
    final checker = ViabilityChecker(
      projectRoot: await fixtureProject(_guarded),
    );
    final flip = flipAt(_guarded, '==', '!=');
    expect(await checker.compiles(flip, _guarded), isFalse);
  });

  test('accepts a flip no downstream code depends on', () async {
    final checker = ViabilityChecker(
      projectRoot: await fixtureProject(_unguarded),
    );
    final flip = flipAt(_unguarded, '==', '!=');
    expect(await checker.compiles(flip, _unguarded), isTrue);
  });

  test('leaves the file on disk untouched between checks', () async {
    final root = await fixtureProject(_guarded);
    final checker = ViabilityChecker(projectRoot: root);
    final broken = flipAt(_guarded, '==', '!=');
    final viable = flipAt(_guarded, 'int.parse', 'int.tryParse');
    expect(await checker.compiles(broken, _guarded), isFalse);
    expect(await checker.compiles(viable, _guarded), isTrue);
    expect(
      File(p.join(root, 'lib', 'a.dart')).readAsStringSync(),
      _guarded,
      reason: 'checks run on overlays, never the working tree',
    );
  });
}
