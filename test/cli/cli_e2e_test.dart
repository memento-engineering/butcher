@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

const _partiallyTestedCalc = '''
int add(int a, int b) => a + b;
bool isEven(int n) => n % 2 == 0;
''';

void main() {
  late RadPaths paths;

  setUp(() async => paths = await isolatedRadPaths('rad_cli_state_'));

  test('produces a Stryker JSON report and kills tested mutants', () async {
    final dir = await createFixturePackage(calc: _partiallyTestedCalc);
    final out = StringBuffer();
    File(p.join(paths.runLogs, 'stale.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('from a previous run');

    final exit = await radMain(
      ['--output', 'report.json', '--jobs', '2', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());

    final logLines = File(paths.toolLog)
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    expect(logLines.first['@mt'], startsWith('starting rad'));
    expect(logLines.last['@mt'], startsWith('run complete'));
    expect(logLines.last['Msi'], closeTo(40, 0.01));
    expect(
      logLines.where((e) => (e['@mt'] as String).startsWith('classified')),
      hasLength(5),
    );
    expect(Directory(paths.runLogs).listSync().whereType<File>(), hasLength(5));
    expect(File(p.join(paths.runLogs, 'stale.log')).existsSync(), isFalse);
    expect(
      out.toString(),
      isNot(contains('@mt')),
      reason: 'non-verbose console stays human-readable',
    );
    final reportFile = File(p.join(dir.path, 'report.json'));
    expect(reportFile.existsSync(), isTrue);

    final report =
        jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
    final file =
        (report['files'] as Map<String, dynamic>)['lib/calc.dart']
            as Map<String, dynamic>;
    final statusById = {
      for (final raw in file['mutants'] as List<dynamic>)
        (raw as Map<String, dynamic>)['id']: raw['status'],
    };

    expect(statusById['lib/calc.dart:27:arithmetic:-'], 'Killed');
    expect(statusById['lib/calc.dart:27:arithmetic:*'], 'Killed');
    expect(statusById['lib/calc.dart:56:arithmetic:*'], 'Survived');
    expect(statusById['lib/calc.dart:60:equality:!='], 'Survived');
    expect(out.toString(), contains('MSI: 40.00%'));

    final untouched = File(p.join(dir.path, 'lib', 'calc.dart'));
    expect(untouched.readAsStringSync(), _partiallyTestedCalc);
  });

  test('gates on --threshold and streams events with --verbose', () async {
    final dir = await createFixturePackage(calc: _partiallyTestedCalc);
    final out = StringBuffer();
    final exit = await radMain(
      ['--threshold', '90', '--verbose', dir.path],
      out: out,
      paths: paths,
    );
    expect(exit, 1, reason: out.toString());
    expect(out.toString(), contains('INF starting rad'));
    expect(out.toString(), contains('as survived'));
    expect(out.toString(), contains('exit 1'));
    expect(out.toString(), isNot(contains('@mt')));
    expect(Directory(paths.runLogs).listSync().whereType<File>(), hasLength(5));
  });

  test('aborts with exit code 70 on a red background reading', () async {
    final dir = await createFixturePackage(
      calc: 'int add(int a, int b) => a * b;\n',
    );
    final exit = await radMain([dir.path], out: StringBuffer(), paths: paths);
    expect(exit, 70);
    final logText = File(paths.toolLog).readAsStringSync();
    expect(logText, contains('"@mt":"run aborted: {Reason}"'));
    expect(logText, contains('"@l":"Error"'));
    expect(Directory(paths.runLogs).existsSync(), isTrue);
    expect(Directory(paths.runLogs).listSync(), isEmpty);
  });

  test('rejects an invalid threshold with exit code 64', () async {
    expect(
      await radMain(['--threshold', 'nope'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await radMain(['--threshold', '101'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('rejects multiple project roots with exit code 64', () async {
    expect(await radMain(['a', 'b'], out: StringBuffer(), paths: paths), 64);
  });

  test('rejects an invalid job count with exit code 64', () async {
    expect(
      await radMain(['--jobs', '0'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await radMain(['--jobs', 'many'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('prints usage with exit code 0 for --help', () async {
    final out = StringBuffer();
    expect(await radMain(['--help'], out: out, paths: paths), 0);
    expect(out.toString(), contains('Usage: rad'));
  });
}
