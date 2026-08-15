import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/containment.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

Future<Directory> fixtureProject() async {
  final dir = await Directory.systemTemp.createTemp('rad_containment_src_');
  addTearDown(() => dir.delete(recursive: true));
  void write(String relative, String content) {
    final file = File(p.join(dir.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  write('lib/a.dart', 'int add(int a, int b) => a + b;\n');
  write('test/a_test.dart', 'void main() {}\n');
  write('.git/config', 'x');
  write('.dart_tool/package_config.json', '{}');
  write('build/out.txt', 'x');
  write('assets/big/blob.bin', 'x');
  write('assets/small.txt', 'keep');
  write('.radignore', '# comment\n\nassets/big/**\n');
  return dir;
}

void main() {
  late Directory source;
  late RadPaths paths;
  late Containment containment;

  setUp(() async {
    source = await fixtureProject();
    paths = await isolatedRadPaths('rad_containment_state_');
    containment = await Containment.create(source.path, paths: paths);
    addTearDown(containment.dispose);
  });

  test('lives inside the configured temp folder', () {
    expect(p.isWithin(paths.root, containment.root), isTrue);
  });

  test('copies the project without excluded paths', () {
    bool has(String relative) =>
        File(p.join(containment.root, relative)).existsSync();
    expect(has('lib/a.dart'), isTrue);
    expect(has('test/a_test.dart'), isTrue);
    expect(has('assets/small.txt'), isTrue);
    expect(has('.git/config'), isFalse);
    expect(has('.dart_tool/package_config.json'), isFalse);
    expect(has('build/out.txt'), isFalse);
    expect(has('assets/big/blob.bin'), isFalse);
  });

  test(
    'applies and restores a mutation without touching the source tree',
    () async {
      const mutation = Mutation(
        filePath: 'lib/a.dart',
        offset: 27,
        length: 1,
        original: '+',
        replacement: '-',
        operatorId: 'arithmetic',
        description: 'replace + with -',
      );
      final copied = File(p.join(containment.root, 'lib/a.dart'));

      await containment.apply(mutation);
      expect(copied.readAsStringSync(), contains('a - b'));
      expect(
        File(p.join(source.path, 'lib/a.dart')).readAsStringSync(),
        contains('a + b'),
      );

      await containment.restore('lib/a.dart');
      expect(copied.readAsStringSync(), contains('a + b'));
    },
  );

  test('rejects a mutation whose original text does not match', () async {
    const drifted = Mutation(
      filePath: 'lib/a.dart',
      offset: 0,
      length: 1,
      original: '+',
      replacement: '-',
      operatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await expectLater(containment.apply(drifted), throwsStateError);
  });
}
