@Timeout(Duration(minutes: 5))
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:butcher/src/engine/sandbox.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

/// One mutant only: `true -> false` never leaves the loop.
const _hangingCalc = '''
bool get ready => true;

int spin() {
  while (!ready) {}
  return 1;
}
''';

const _hangingTest = '''
import 'package:fixture/calc.dart';
import 'package:test/test.dart';

void main() {
  test('spins', () => expect(spin(), 1));
}
''';

/// Collects what the CLI writes to `stderr` under [IOOverrides].
final class _CapturedStderr implements Stdout {
  final _buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  String toString() => _buffer.toString();
}

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('butcher_cli_run_'));

  test('produces a Stryker JSON report and kills tested mutants', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    final out = StringBuffer();
    File(p.join(paths.runLogs, 'stale.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('from a previous run');

    final exit = await butcherMain(
      [
        '--output',
        'report.json',
        '--jobs',
        '2',
        '--no-collect-coverage',
        dir.path,
      ],
      out: out,
      paths: paths,
    );

    expect(exit, 0, reason: out.toString());

    final logLines = File(paths.toolLog)
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    expect(logLines.first['@mt'], startsWith('starting butcher'));
    expect(
      logLines.map((e) => e['@mt']),
      isNot(contains(startsWith('collected coverage'))),
      reason: '--no-collect-coverage treats all code as covered instead',
    );
    expect(logLines.last['@mt'], startsWith('run complete'));
    expect(logLines.last['Msi'], closeTo(40, 0.01));
    expect(
      logLines.where((e) => (e['@mt'] as String).startsWith('classified')),
      hasLength(5),
    );
    final runLogs = Directory(paths.runLogs).listSync().whereType<File>();
    expect(
      runLogs.map((file) => p.basename(file.path)),
      everyElement(startsWith(sandboxPrefix)),
      reason: 'one run log per sandbox, named after it',
    );
    expect(runLogs, hasLength(2), reason: 'one per --jobs worker');
    expect(File(p.join(paths.runLogs, 'stale.log')).existsSync(), isFalse);
    expect(
      Directory(paths.root).listSync().whereType<Directory>().where(
        (directory) => p.basename(directory.path).startsWith(sandboxPrefix),
      ),
      hasLength(3),
      reason:
          'the baseline plus one per --jobs worker, all kept '
          'until the next run starts',
    );
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
    expect(untouched.readAsStringSync(), fixturePartiallyTestedCalc);
    expect(
      File(paths.lockFile).existsSync(),
      isFalse,
      reason: 'a clean exit releases the run lock',
    );
  });

  test('gates on --threshold and streams events with --verbose', () async {
    final dir = await createFixturePackage(calc: fixturePartiallyTestedCalc);
    final out = StringBuffer();
    final exit = await butcherMain(
      ['--threshold', '90', '--verbose', '--no-collect-coverage', dir.path],
      out: out,
      paths: paths,
    );
    expect(exit, 1, reason: out.toString());
    expect(out.toString(), contains('INF starting butcher'));
    expect(out.toString(), contains('as survived'));
    expect(out.toString(), contains('exit 1'));
    expect(out.toString(), isNot(contains('@mt')));
    expect(Directory(paths.runLogs).listSync().whereType<File>(), isNotEmpty);
  });

  test('gates on --max-timeouts and scores timeouts as neither', () async {
    final dir = await createFixturePackage(
      calc: _hangingCalc,
      testSource: _hangingTest,
    );
    final out = StringBuffer();

    final exit = await butcherMain(
      ['--max-timeouts', '0', '--no-collect-coverage', dir.path],
      out: out,
      paths: paths,
    );

    expect(exit, 1, reason: out.toString());
    expect(out.toString(), contains('timeout: 1'));
    expect(out.toString(), contains('MSI: none (no scoreable mutants)'));
    expect(out.toString(), contains('Timeout rate: 100.00%'));
  });

  test('fails the threshold closed when no mutant is scoreable', () async {
    final dir = await createFixturePackage(calc: 'int add(int a, int b) => 5;');
    final captured = _CapturedStderr();

    final exit = await IOOverrides.runZoned(
      () => butcherMain(
        ['--threshold', '50', '--no-collect-coverage', dir.path],
        out: StringBuffer(),
        paths: paths,
      ),
      stderr: () => captured,
    );

    expect(exit, 1);
    expect(
      captured.toString(),
      contains('no scoreable mutants, so no MSI: the 50.00% threshold'),
    );
  });
}
