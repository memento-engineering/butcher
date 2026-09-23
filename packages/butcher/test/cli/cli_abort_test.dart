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

/// [s] as it appears inside a JSON string value, quotes stripped: the tool
/// log is one JSON object per line, so a Windows path's backslashes arrive
/// escaped and a raw path never matches it directly.
String jsonText(String s) =>
    jsonEncode(s).substring(1, jsonEncode(s).length - 1);

final class ThrowingSink implements StringSink {
  Never _fail() => throw StateError('console failed');

  @override
  void write(Object? object) => _fail();

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();

  @override
  void writeCharCode(int charCode) => _fail();

  @override
  void writeln([Object? object = '']) => _fail();
}

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('butcher_cli_abort_'));

  test('aborts with exit code 70 while another run holds the lock', () async {
    final held = RunWorkspace.acquire(paths);
    addTearDown(held.release);
    final evidence = File(p.join(paths.runLogs, '${sandboxPrefix}active.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('from the active run');

    final exit = await butcherMain([], out: StringBuffer(), paths: paths);

    expect(exit, 70);
    expect(
      evidence.existsSync(),
      isTrue,
      reason: 'cleanup must not touch an active run\'s evidence',
    );
  });

  test('aborts with exit code 70 on a red baseline', () async {
    final dir = await createFixturePackage(
      calc: 'int add(int a, int b) => a * b;\n',
    );
    final exit = await butcherMain(
      [dir.path],
      out: StringBuffer(),
      paths: paths,
    );
    expect(exit, 70);
    final logText = File(paths.toolLog).readAsStringSync();
    expect(logText, contains('"@mt":"run aborted: {Reason}"'));
    expect(logText, contains('"@l":"Error"'));
    expect(Directory(paths.runLogs).existsSync(), isTrue);
    expect(Directory(paths.runLogs).listSync(), isEmpty);
    expect(
      Directory(paths.root).listSync().whereType<Directory>().any(
        (directory) => p.basename(directory.path).startsWith(sandboxPrefix),
      ),
      isTrue,
      reason: 'aborted-run sandbox remains until the next run starts',
    );
  });

  test('aborts with exit code 70 on a too-old package:test', () async {
    final dir = await createFixturePackage();
    // The project's lockfile still pins a new package:test; only the
    // sandbox's re-resolved dependencies can tell.
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst('test: any', 'test: 1.24.5'),
    );

    expect(
      await butcherMain([dir.path], out: StringBuffer(), paths: paths),
      70,
    );
    expect(
      File(paths.toolLog).readAsStringSync(),
      contains('does not support --fail-fast'),
    );
    expect(
      Directory(paths.root).listSync().whereType<Directory>().where(
        (directory) => p.basename(directory.path).startsWith(sandboxPrefix),
      ),
      hasLength(1),
      reason: 'the version check precedes the template clone',
    );
  });

  test('releases the lock when the project root does not exist', () async {
    final missing = p.join(paths.root, 'no_such_project');

    expect(await butcherMain([missing], out: StringBuffer(), paths: paths), 70);

    expect(File(paths.toolLog).readAsStringSync(), contains(jsonText(missing)));
    expect(
      File(paths.lockFile).existsSync(),
      isFalse,
      reason: 'an aborted run must not strand the lock',
    );
  });

  test('releases the lock when initial logging fails', () async {
    await expectLater(
      butcherMain(
        ['--verbose', '--no-collect-coverage'],
        out: ThrowingSink(),
        paths: paths,
      ),
      throwsStateError,
    );

    expect(File(paths.lockFile).existsSync(), isFalse);
  });
}
