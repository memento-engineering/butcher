import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/sandbox.dart';
import 'package:test/test.dart';

import 'helpers/paths.dart';

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('butcher_workspace_'));

  test('cleans leftover state and keeps the run-log directory', () {
    File(paths.toolLog).writeAsStringSync('from a previous run');
    Directory(p.join(paths.root, '${sandboxPrefix}old')).createSync();
    File(p.join(paths.runLogs, '${sandboxPrefix}old.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('stale evidence');
    File(p.join(paths.root, 'unrelated.txt')).writeAsStringSync('keep me');

    RunWorkspace.acquire(paths).clean();

    expect(File(paths.toolLog).existsSync(), isFalse);
    expect(
      Directory(p.join(paths.root, '${sandboxPrefix}old')).existsSync(),
      false,
    );
    expect(Directory(paths.runLogs).existsSync(), isTrue);
    expect(Directory(paths.runLogs).listSync(), isEmpty);
    expect(File(p.join(paths.root, 'unrelated.txt')).existsSync(), isTrue);
    expect(File(paths.lockFile).existsSync(), isTrue);
  });

  test('never steals a held lock', () {
    final held = RunWorkspace.acquire(paths);

    expect(() => RunWorkspace.acquire(paths), throwsA(isA<RunAborted>()));

    held.release();
    expect(File(paths.lockFile).existsSync(), isFalse);
    expect(RunWorkspace.acquire(paths), isA<RunWorkspace>());
  });

  test('releases the lock when startup cleanup fails', () {
    File(paths.runLogs).writeAsStringSync('not a directory');
    final workspace = RunWorkspace.acquire(paths);

    expect(workspace.clean, throwsA(isA<RunAborted>()));

    expect(File(paths.lockFile).existsSync(), isFalse);
    expect(RunWorkspace.acquire(paths), isA<RunWorkspace>());
  });
}
