import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

const _source = '''
int add(int a, int b) => a + b;
int sub(int a, int b) => a - b;
int mul(int a, int b) => a * b;
''';

Mutant mutantAt(int line, {String file = 'lib/calc.dart'}) => Mutant(
  id: '$file:$line',
  mutation: Mutation(
    // Every source line is 31 characters wide, newline included.
    filePath: file,
    offset: (line - 1) * 31 + 26,
    length: 1,
    original: '+',
    replacement: '-',
    mutatorId: 'arithmetic',
    description: 'replace + with -',
  ),
);

void main() {
  final root = p.join(Directory.systemTemp.path, 'rad_lcov_fake');
  final sources = {'lib/calc.dart': _source};

  test('reads hits per line from absolute and relative SF records', () {
    final provider = LcovCoverageProvider.parse('''
SF:${p.join(root, 'lib', 'calc.dart')}
DA:1,3
DA:2,0
end_of_record
SF:lib/other.dart
DA:1,1
end_of_record
''', projectRoot: root)..indexSources(sources);

    expect(provider.hits.keys, ['lib/calc.dart', 'lib/other.dart']);
    expect(provider.hits['lib/calc.dart'], {1: 3, 2: 0});
    expect(provider.isCovered(mutantAt(1)), isTrue);
    expect(provider.isCovered(mutantAt(2)), isFalse, reason: 'zero hits');
    expect(
      provider.isCovered(mutantAt(3)),
      isTrue,
      reason: 'an unrecorded line is no statement of its own',
    );
  });

  test('reports mutants in files the report omits as uncovered', () {
    final provider = LcovCoverageProvider.parse(
      'SF:lib/other.dart\nDA:1,1\nend_of_record\n',
      projectRoot: root,
    )..indexSources(sources);

    expect(provider.isCovered(mutantAt(1)), isFalse);
  });

  test('sums hits repeated for one line and ignores other records', () {
    final provider = LcovCoverageProvider.parse('''
TN:
SF:lib/calc.dart
FN:1,add
DA:1,0
DA:1,2
LH:1
end_of_record
''', projectRoot: root)..indexSources(sources);

    expect(provider.hits['lib/calc.dart'], {1: 2});
    expect(provider.isCovered(mutantAt(1)), isTrue);
  });

  test(
    'maps offsets with the captured sources, not the working tree',
    () async {
      final dir = await Directory.systemTemp.createTemp('rad_lcov_');
      addTearDown(() => dir.delete(recursive: true));
      File(p.join(dir.path, 'lib', 'calc.dart'))
        ..parent.createSync(recursive: true)
        // A mid-run edit prepends a line, shifting every offset one line down.
        ..writeAsStringSync('// edited\n$_source');
      final provider = LcovCoverageProvider.parse(
        'SF:lib/calc.dart\nDA:1,1\nDA:2,0\nend_of_record\n',
        projectRoot: dir.path,
      )..indexSources(sources);

      expect(provider.isCovered(mutantAt(2)), isFalse);
    },
  );
}
