@Timeout(Duration(minutes: 5))
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

void main() {
  late RadPaths paths;

  setUp(() async => paths = await isolatedRadPaths('rad_cli_coverage_'));

  test('routes from lcov: mutants on unhit lines never run', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    final lcov = File(p.join(dir.path, 'coverage', 'lcov.info'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('SF:lib/calc.dart\nDA:1,4\nDA:2,0\nend_of_record\n');
    final out = StringBuffer();

    final exit = await radMain(
      ['--coverage', lcov.path, '--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(out.toString(), contains('killed: 2'));
    expect(out.toString(), contains('noCoverage: 3'));
    expect(out.toString(), contains('MSI: 40.00%'));
    expect(out.toString(), contains('Covered-code MSI: 100.00%'));
    expect(
      File(paths.toolLog).readAsStringSync(),
      contains('"@mt":"ingested coverage for {FileCount} files from {Path}"'),
    );
  });

  test('collects coverage and skips what no test reaches', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    File(p.join(dir.path, 'lib', 'unused.dart'))
        .writeAsStringSync('int mul(int a, int b) => a * b;\n');
    final out = StringBuffer();

    final exit = await radMain(
      ['--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(out.toString(), contains('killed: 2'));
    expect(
      out.toString(),
      contains('noCoverage: 6'),
      reason: 'the unhit lines of calc.dart plus the file no test loads',
    );
    expect(out.toString(), contains('Covered-code MSI: 100.00%'));
    expect(
      File(paths.toolLog).readAsStringSync(),
      contains('"@mt":"collected coverage for {FileCount} files'),
    );
    final routed = Directory(paths.runLogs)
        .listSync()
        .whereType<File>()
        .expand((file) => file.readAsLinesSync())
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((event) => event.containsKey('MutantId'))
        .map((event) => event['Suites']);
    expect(
      routed,
      everyElement(['test/calc_test.dart']),
      reason: 'collected coverage routes each mutant to its covering suites',
    );
  });

  test('routes from coverage/lcov.info without --coverage', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    File(p.join(dir.path, 'coverage', 'lcov.info'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('SF:lib/calc.dart\nDA:1,4\nDA:2,0\nend_of_record\n');
    final out = StringBuffer();

    final exit = await radMain(
      ['--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(out.toString(), contains('noCoverage: 3'));
    final logText = File(paths.toolLog).readAsStringSync();
    expect(logText, contains('"@mt":"ingested coverage for {FileCount} files'));
    expect(
      logText,
      isNot(contains('collected coverage')),
      reason: 'a report in the project preempts collection',
    );
  });

  test('collects when coverage/lcov.info records nothing', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    File(p.join(dir.path, 'coverage', 'lcov.info'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');
    final out = StringBuffer();

    final exit = await radMain(
      ['--jobs', '1', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());
    expect(
      out.toString(),
      contains('killed: 2'),
      reason: 'a stale report must not route every mutant to noCoverage',
    );
    final logText = File(paths.toolLog).readAsStringSync();
    expect(
      logText,
      contains('"@mt":"collected coverage for {FileCount} files'),
    );
    expect(logText, isNot(contains('ingested coverage')));
  });
}
