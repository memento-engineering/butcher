import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/mutant_generator.dart';
import 'package:test/test.dart';

Future<Directory> fixtureProject() async {
  final dir = await Directory.systemTemp.createTemp('rad_gen_');
  addTearDown(() => dir.delete(recursive: true));
  final src = Directory(p.join(dir.path, 'lib', 'src'))
    ..createSync(recursive: true);
  File(p.join(dir.path, 'lib', 'a.dart'))
      .writeAsStringSync('int add(int a, int b) => a + b;\n');
  File(p.join(src.path, 'b.dart'))
      .writeAsStringSync('bool both(bool a, bool b) => a && b;\n');
  File(p.join(dir.path, 'lib', 'gen.g.dart'))
      .writeAsStringSync('int genAdd(int a, int b) => a + b;\n');
  return dir;
}

void main() {
  test(
    'generates sorted mutants with stable ids, skipping generated files',
    () async {
      final dir = await fixtureProject();
      final generator = MutantGenerator(
        projectRoot: dir.path,
        registry: MutagenRegistry.defaults(),
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

  test('returns no mutants without a lib directory', () async {
    final dir = await Directory.systemTemp.createTemp('rad_gen_empty_');
    addTearDown(() => dir.delete(recursive: true));
    final (mutants, sources) = await MutantGenerator(
      projectRoot: dir.path,
      registry: MutagenRegistry.defaults(),
    ).generate();
    expect(mutants, isEmpty);
    expect(sources, isEmpty);
  });
}
