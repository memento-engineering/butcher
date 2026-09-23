@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

void main() {
  late RadPaths paths;

  setUp(() async => paths = await isolatedRadPaths('rad_cli_provisioning_'));

  test('provisions an unresolved project before analysing it', () async {
    final dir = await createFixturePackage(resolve: false);
    final out = StringBuffer();

    final exit = await radMain(
      ['--no-collect-coverage', '--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(File(p.join(dir.path, 'pubspec.lock')).existsSync(), isTrue);
    expect(
      File(p.join(dir.path, '.dart_tool', 'package_config.json')).existsSync(),
      isTrue,
    );
    expect(out.toString(), contains('killed: 2'));
    expect(
      File(paths.toolLog).readAsStringSync(),
      contains('"@mt":"provisioned {ProjectRoot} in {DurationMs} ms"'),
    );
  });

  test('refreshes stale project dependencies before analysing it', () async {
    final dir = await createFixturePackage();
    File(p.join(dir.path, 'dependency', 'pubspec.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
name: dependency
environment:
  sdk: ^3.0.0
''');
    File(p.join(dir.path, 'dependency', 'lib', 'value.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('const extra = 0;\n');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
environment:
  sdk: ^3.0.0
dependencies:
  dependency:
    path: dependency
dev_dependencies:
  test: any
''');
    File(p.join(dir.path, 'lib', 'calc.dart')).writeAsStringSync('''
import 'package:dependency/value.dart';

int add(int a, int b) => a + b + extra;
''');
    final out = StringBuffer();

    final exit = await radMain(
      ['--no-collect-coverage', '--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(out.toString(), contains('killed:'));
    expect(
      out.toString(),
      isNot(contains('unviable:')),
      reason: 'analysis must use the dependency added after the first pub get',
    );
  });
}
