import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/mutant_generator.dart';
import 'package:butcher/src/config/mutation_scope.dart';
import 'package:test/test.dart';

Future<Directory> fixtureProject() async {
  final dir = await Directory.systemTemp.createTemp('butcher_gen_');
  addTearDown(() => dir.delete(recursive: true));
  final src = Directory(p.join(dir.path, 'lib', 'src'))
    ..createSync(recursive: true);
  File(
    p.join(dir.path, 'lib', 'a.dart'),
  ).writeAsStringSync('int add(int a, int b) => a + b;\n');
  File(
    p.join(src.path, 'b.dart'),
  ).writeAsStringSync('bool both(bool a, bool b) => a && b;\n');
  File(
    p.join(dir.path, 'lib', 'gen.g.dart'),
  ).writeAsStringSync('int genAdd(int a, int b) => a + b;\n');
  return dir;
}

void main() {
  test(
    'generates sorted mutants with stable ids, skipping generated files',
    () async {
      final dir = await fixtureProject();
      final generator = MutantGenerator(
        projectRoot: dir.path,
        registry: MutatorRegistry.defaults(),
        isExcluded: MutationScope.load(dir.path).excludes,
      );
      final (mutants, sources) = await generator.generate();

      expect(mutants.map((m) => m.mutation.filePath).toSet(), {
        'lib/a.dart',
        'lib/src/b.dart',
      });
      expect(mutants.map((m) => m.id), [
        'lib/a.dart:27:arithmetic:*',
        'lib/a.dart:27:arithmetic:-',
        'lib/src/b.dart:31:logical:||',
      ]);
      expect(sources['lib/a.dart'], 'int add(int a, int b) => a + b;\n');
      expect(sources.keys, isNot(contains('lib/gen.g.dart')));

      final (second, _) = await generator.generate();
      expect(second.map((m) => m.id), mutants.map((m) => m.id));
    },
  );

  test('skips files excluded by butcher.yaml', () async {
    final dir = await fixtureProject();
    File(
      p.join(dir.path, butcherConfigFile),
    ).writeAsStringSync('exclude:\n  - lib/src/**\n');
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, ['lib/a.dart']);
    expect(mutants.map((m) => m.mutation.filePath), everyElement('lib/a.dart'));
  });

  test('skips dart files inside tooling directories', () async {
    final dir = await fixtureProject();
    File(p.join(dir.path, 'lib', '.dart_tool', 'cached.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('int mul(int a, int b) => a * b;\n');
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, isNot(contains('lib/.dart_tool/cached.dart')));
    expect(
      mutants.map((m) => m.mutation.filePath),
      everyElement(isNot('lib/.dart_tool/cached.dart')),
      reason: 'no sandbox copies it, so no mutant may target it',
    );
  });

  test('skips dart files inside a git directory', () async {
    final dir = await fixtureProject();
    File(p.join(dir.path, 'lib', '.git', 'hook.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('int mul(int a, int b) => a * b;\n');
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, isNot(contains('lib/.git/hook.dart')));
    expect(
      mutants.map((m) => m.mutation.filePath),
      everyElement(isNot('lib/.git/hook.dart')),
      reason: 'no sandbox copies it, so no mutant may target it',
    );
  });

  test('skips files that are not dart sources', () async {
    final dir = await fixtureProject();
    File(
      p.join(dir.path, 'lib', 'notes.txt'),
    ).writeAsStringSync('int add(int a, int b) => a + b;\n');
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, isNot(contains('lib/notes.txt')));
    expect(
      mutants.map((m) => m.mutation.filePath),
      everyElement(isNot('lib/notes.txt')),
    );
  });

  test('skips generated dart files under lib', () async {
    final dir = await fixtureProject();
    File(
      p.join(dir.path, 'lib', 'model.freezed.dart'),
    ).writeAsStringSync('int add(int a, int b) => a + b;\n');
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, isNot(contains('lib/model.freezed.dart')));
    expect(
      mutants.map((m) => m.mutation.filePath),
      everyElement(isNot('lib/model.freezed.dart')),
    );
  });

  test('does not follow symlinks', () async {
    final dir = await fixtureProject();
    final outside = await Directory.systemTemp.createTemp('butcher_gen_link_');
    addTearDown(() => outside.delete(recursive: true));
    final target = File(p.join(outside.path, 'linked.dart'))
      ..writeAsStringSync('int mul(int a, int b) => a * b;\n');
    try {
      Link(p.join(dir.path, 'lib', 'linked.dart')).createSync(target.path);
    } on FileSystemException {
      markTestSkipped('symlinks are unavailable on this system');
      return;
    }
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(sources.keys, isNot(contains('lib/linked.dart')));
    expect(
      mutants.map((m) => m.mutation.filePath),
      everyElement(isNot('lib/linked.dart')),
    );
  });

  test('returns no mutants without a lib directory', () async {
    final dir = await Directory.systemTemp.createTemp('butcher_gen_empty_');
    addTearDown(() => dir.delete(recursive: true));
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutatorRegistry.defaults(),
      isExcluded: MutationScope.load(dir.path).excludes,
    ).generate();
    expect(mutants, isEmpty);
    expect(sources, isEmpty);
  });
}
