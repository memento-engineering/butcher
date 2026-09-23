@Timeout(Duration(minutes: 2))
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

/// A suite that starts a process of its own, records its pid, then hangs:
/// what rad's own suite does to every mutant of it.
const _spawningTest = '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('spawns and hangs', () async {
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

/// Whether [pid] is listed among the running processes.
Future<bool> isRunning(int pid) async {
  final snapshot = await DartTestRunner.processSnapshot();
  return LineSplitter.split(
    snapshot,
  ).any((line) => int.tryParse(line.trim().split(RegExp(r'\s+')).first) == pid);
}

void main() {
  test('kills what the suite spawned, not just the suite', () async {
    final dir = await createFixturePackage(testSource: _spawningTest);
    File(p.join(dir.path, 'spinner.dart')).writeAsStringSync(_spinner);

    final run = await DartTestRunner(
      dir.path,
    ).run(timeout: const Duration(seconds: 25));

    expect(run.timedOut, isTrue);
    final record = File(p.join(dir.path, 'child.pid'));
    expect(
      record.existsSync(),
      isTrue,
      reason: 'the suite must reach its spawn before the deadline',
    );
    final child = int.parse(record.readAsStringSync());
    expect(
      await isRunning(child),
      isFalse,
      reason: 'a process the suite started outlives it unless swept',
    );
  });
}
