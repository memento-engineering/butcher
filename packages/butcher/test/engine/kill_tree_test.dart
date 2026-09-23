@Timeout(Duration(minutes: 2))
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

/// A suite that records its own pid, starts a process of its own, records
/// that one too, then hangs: what butcher's own suite does to every mutant
/// of it.
const _spawningTest = '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('spawns and hangs', () async {
    File('suite.pid').writeAsStringSync('\$pid');
    final child = await Process.start(Platform.resolvedExecutable, [
      'run',
      'spinner.dart',
    ]);
    File('child.pid').writeAsStringSync('\${child.pid}');
    while (true) {}
  });
}
''';

const _spinner = '''
void main() {
  while (true) {}
}
''';

/// Whether [pid] is still a live process.
///
/// A killed process whose parent died with it is reparented and reaped, and
/// until that happens it is listed in state `Z`: a table entry, not a
/// survivor.
Future<bool> isRunning(int pid) async {
  final listed = Platform.isWindows
      ? await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-Process -Id $pid -ErrorAction SilentlyContinue | '
              'Select-Object -ExpandProperty Id',
        ])
      : await Process.run('/bin/ps', ['-p', '$pid', '-o', 'stat=']);
  final state = '${listed.stdout}'.trim();
  return state.isNotEmpty && !state.startsWith('Z');
}

/// The pid the hung suite wrote to [name] before its deadline.
int recordedPid(Directory dir, String name) {
  final file = File(p.join(dir.path, name));
  expect(
    file.existsSync(),
    isTrue,
    reason: 'the suite must reach $name before the deadline',
  );
  return int.parse(file.readAsStringSync());
}

void main() {
  test('kills what the suite spawned, not just the suite', () async {
    final dir = await createFixturePackage(testSource: _spawningTest);
    File(p.join(dir.path, 'spinner.dart')).writeAsStringSync(_spinner);

    final run = await DartTestRunner(
      dir.path,
    ).run(timeout: const Duration(seconds: 25));

    expect(run.timedOut, isTrue, reason: 'the deadline must fire');
    expect(run.exitCode, -1, reason: 'a killed suite reports no exit code');
    expect(
      await isRunning(recordedPid(dir, 'suite.pid')),
      isFalse,
      reason: 'the suite itself dies at its deadline',
    );
    expect(
      await isRunning(recordedPid(dir, 'child.pid')),
      isFalse,
      reason: 'a process the suite started dies with the suite group',
    );
  });
}
