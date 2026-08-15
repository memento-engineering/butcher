import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Default library source of the fixture package.
const fixtureCalc = 'int add(int a, int b) => a + b;\n';

/// Default suite of the fixture package: kills the `+ → -` mutant.
const fixtureTest = '''
import 'package:fixture/calc.dart';
import 'package:test/test.dart';

void main() {
  test('adds', () => expect(add(2, 3), 5));
}
''';

/// Creates a resolvable single-package fixture with one lib and one suite.
Future<Directory> createFixturePackage({
  String calc = fixtureCalc,
  String testSource = fixtureTest,
}) async {
  final dir = await Directory.systemTemp.createTemp('rad_fixture_');
  addTearDown(() => dir.delete(recursive: true));
  void write(String relative, String content) {
    final file = File(p.join(dir.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  write('pubspec.yaml', '''
name: fixture
environment:
  sdk: ^3.0.0
dev_dependencies:
  test: any
''');
  write('lib/calc.dart', calc);
  write('test/calc_test.dart', testSource);

  final pubGet = await Process.run(Platform.resolvedExecutable, [
    'pub',
    'get',
  ], workingDirectory: dir.path);
  if (pubGet.exitCode != 0) {
    fail('fixture pub get failed: ${pubGet.stdout}${pubGet.stderr}');
  }
  return dir;
}
