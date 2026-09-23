import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/mutant_generator.dart';
import 'package:butcher/src/engine/project_analysis.dart';
import 'package:butcher/src/engine/rad_ignore.dart';
import 'package:butcher/src/engine/viability_checker.dart';
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

Future<String> fixtureProject(Map<String, String> files) async {
  final dir = await Directory.systemTemp.createTemp('rad_viability_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'pubspec.yaml'))
      .writeAsStringSync('name: fixture\nenvironment:\n  sdk: ^3.0.0\n');
  files.forEach(
    (name, source) => File(p.join(dir.path, 'lib', name))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source),
  );
  return dir.path;
}

Mutant flipAt(
  String file,
  String source,
  String original,
  String replacement,
) => Mutant(
  id: '$file:$original>$replacement',
  mutation: Mutation(
    filePath: 'lib/$file',
    offset: source.indexOf(original),
    length: original.length,
    original: original,
    replacement: replacement,
    operatorId: 'equality',
    description: 'replace $original with $replacement',
  ),
);

void main() {
  test('judges same-file mutants independently in any order', () async {
    final root = await fixtureProject({'a.dart': _guarded});
    final broken = flipAt('a.dart', _guarded, '==', '!=');
    final viable = flipAt('a.dart', _guarded, 'int.parse', 'int.tryParse');
    for (final batch in [
      [broken, viable],
      [viable, broken],
    ]) {
      final unviable = await ViabilityChecker(
        analysis: ProjectAnalysis(projectRoot: root),
      ).unviable(batch, {'lib/a.dart': _guarded});
      expect(unviable, {broken.id}, reason: 'order must not leak overlays');
    }
  });

  test('keeps verdicts apart across files and leaves them on disk', () async {
    final root = await fixtureProject({
      'a.dart': _guarded,
      'b.dart': _unguarded,
    });
    final broken = flipAt('a.dart', _guarded, '==', '!=');
    final fine = flipAt('b.dart', _unguarded, '==', '!=');
    final unviable =
        await ViabilityChecker(analysis: ProjectAnalysis(projectRoot: root))
            .unviable(
              [broken, fine],
              {'lib/a.dart': _guarded, 'lib/b.dart': _unguarded},
            );
    expect(unviable, {broken.id});
    expect(File(p.join(root, 'lib', 'a.dart')).readAsStringSync(), _guarded);
    expect(File(p.join(root, 'lib', 'b.dart')).readAsStringSync(), _unguarded);
  });

  test('reuses the generator analysis and restores it afterwards', () async {
    final root = await fixtureProject({'a.dart': _guarded});
    final generator = MutantGenerator(
      projectRoot: root,
      registry: MutagenRegistry.defaults(),
      ignore: RadIgnore.load(root),
    );
    final (mutants, sources) = await generator.generate();
    final unviable = await ViabilityChecker(analysis: generator.analysis)
        .unviable(mutants, sources);
    expect(mutants, isNotEmpty);
    expect(unviable.length, lessThan(mutants.length));

    final (again, _) = await generator.generate();
    expect(
      again.map((m) => m.id),
      mutants.map((m) => m.id),
      reason: 'the shared analysis must be free of mutated overlays',
    );
  });
}
