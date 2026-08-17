import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/containment.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

Future<Directory> fixtureProject({Directory? parent}) async {
  final dir = await (parent ?? Directory.systemTemp).createTemp(
    'rad_containment_src_',
  );
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
  write('assets/big/keep.txt', 'keep');
  write('assets/small.txt', 'keep');
  write('deep/nested/trace.log', 'x');
  write(
    '.radignore',
    '# comment\n\n*.log\nassets/big/**\n!assets/big/keep.txt\n',
  );
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
    expect(has('assets/big/keep.txt'), isTrue);
    expect(has('deep/nested/trace.log'), isFalse);
  });

  test('does not copy an in-project rad root', () async {
    final project = await fixtureProject();
    final inProject = RadPaths(root: p.join(project.path, '.rad_temp'));
    final copy = await Containment.create(project.path, paths: inProject);
    expect(Directory(p.join(copy.root, '.rad_temp')).existsSync(), isFalse);
    expect(File(p.join(copy.root, 'lib/a.dart')).existsSync(), isTrue);
  });

  test('copies the project when the rad root is an ancestor', () async {
    final ancestor = await Directory.systemTemp.createTemp('rad_ancestor_');
    addTearDown(() => ancestor.delete(recursive: true));
    final project = await fixtureProject(parent: ancestor);
    final copy = await Containment.create(
      project.path,
      paths: RadPaths(root: ancestor.path),
    );
    expect(File(p.join(copy.root, 'lib/a.dart')).existsSync(), isTrue);
  });

  test('copies the project when the rad root equals it', () async {
    final project = await fixtureProject();
    final copy = await Containment.create(
      project.path,
      paths: RadPaths(root: project.path),
    );
    expect(File(p.join(copy.root, 'lib/a.dart')).existsSync(), isTrue);
    expect(Directory(p.join(copy.root, copy.name)).existsSync(), isFalse);
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

  test('rejects a mutation past the end of the copied file', () async {
    const pastEnd = Mutation(
      filePath: 'lib/a.dart',
      offset: 1000,
      length: 1,
      original: '+',
      replacement: '-',
      operatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await expectLater(containment.apply(pastEnd), throwsStateError);
  });
}
