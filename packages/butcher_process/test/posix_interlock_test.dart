@TestOn('posix')
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:butcher_process/src/posix_interlock.dart';
import 'package:test/test.dart';

/// Whether [pid] is still listed by the OS.
Future<bool> isRunning(int pid) async {
  final listed = await Process.run('/bin/ps', ['-p', '$pid', '-o', 'pid=']);
  return '${listed.stdout}'.trim().isNotEmpty;
}

/// The first [count] lines of [process]'s stdout, read as pids while the
/// stream keeps draining.
Future<List<int>> reportedPids(Process process, int count) {
  final pids = <int>[];
  final read = Completer<List<int>>();
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      if (read.isCompleted) return;
      pids.add(int.parse(line.trim()));
      if (pids.length == count) read.complete(pids);
    },
  );
  return read.future;
}

/// A shell program reporting the pids of [count] children it leaves running.
///
/// It then blocks in a builtin rather than in a process of its own, so the
/// reported pids are the only children a test has to account for.
String spawner(int count) => [
  for (var child = 0; child < count; child++) r'sleep 120 & echo $!',
  'wait',
].join('; ');

void main() {
  test('resolves the ladder once, at construction', () async {
    final probed = <String>[];
    final interlock = PosixInterlock(
      probe: (executable) {
        probed.add(executable);
        return File(executable).existsSync();
      },
    );
    expect(probed, isNotEmpty, reason: 'the ladder resolves at construction');

    final atConstruction = [...probed];
    final first = await interlock.start('/bin/sh', ['-c', 'exit 0']);
    await first.exitCode;
    final second = await interlock.start('/bin/sh', ['-c', 'exit 0']);
    await second.exitCode;

    expect(probed, atConstruction, reason: 'a start does not re-resolve');
    interlock.dispose();
  });

  test('the started process leads its own process group', () async {
    final interlock = PosixInterlock();
    final process = await interlock.start('/bin/sh', [
      '-c',
      r'echo $$; sleep 120',
    ]);
    // The shim sets the group and then execs, so the contract holds from the
    // first byte the started program writes, not from the start itself.
    expect((await reportedPids(process, 1)).single, process.pid);

    expect(PosixInterlock.processGroupOf(process.pid), process.pid);

    await interlock.terminate(process);
    interlock.dispose();
  });

  test('terminate kills the grandchildren with the child', () async {
    final interlock = PosixInterlock();
    final process = await interlock.start('/bin/sh', ['-c', spawner(2)]);
    final grandchildren = await reportedPids(process, 2);

    await interlock.terminate(process);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    for (final pid in grandchildren) {
      expect(
        await isRunning(pid),
        isFalse,
        reason: 'no member of the group survives the kill',
      );
    }
    expect(await isRunning(process.pid), isFalse);
    interlock.dispose();
  });

  test('a descendant with its own session escapes the group', () async {
    final directory = Directory.systemTemp.createTempSync('butcher_process');
    addTearDown(() => directory.deleteSync(recursive: true));
    final script = File('${directory.path}/escapee.pl')
      ..writeAsStringSync(r'''
use POSIX;
POSIX::setsid() or die "no session: $!\n";
$| = 1;
print "$$\n";
sleep 120;
''');

    final interlock = PosixInterlock();
    final process = await interlock.start('/bin/sh', [
      '-c',
      '/usr/bin/perl ${script.path} & wait',
    ]);
    final escapee = (await reportedPids(process, 1)).single;

    await interlock.terminate(process);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      await isRunning(escapee),
      isTrue,
      reason:
          'a descendant that creates its own session leaves the group; it was '
          'equally unreachable from the process listing this replaces',
    );
    Process.killPid(escapee, ProcessSignal.sigkill);
    interlock.dispose();
  });

  group('without a shim', () {
    test('kills the pid alone and says so', () async {
      final diagnostics = <String>[];
      final interlock = PosixInterlock(
        ladder: const [],
        diagnostics: diagnostics.add,
      );
      expect(diagnostics, hasLength(1), reason: 'one loud diagnostic');

      final process = await interlock.start('/bin/sh', ['-c', spawner(1)]);
      final grandchild = (await reportedPids(process, 1)).single;

      expect(
        PosixInterlock.processGroupOf(process.pid),
        isNot(process.pid),
        reason: 'no shim, so the process stays in this process group',
      );

      await interlock.terminate(process);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(await isRunning(process.pid), isFalse);
      expect(
        await isRunning(grandchild),
        isTrue,
        reason: 'the fallback kills the pid alone, and does not sweep',
      );
      Process.killPid(grandchild, ProcessSignal.sigkill);
      interlock.dispose();
    });

    test('names the shim it could not find', () {
      final diagnostics = <String>[];
      PosixInterlock(
        ladder: const [
          (executable: '/no/such/setsid', arguments: <String>[]),
          (executable: '/no/such/perl', arguments: <String>[]),
        ],
        diagnostics: diagnostics.add,
      ).dispose();

      expect(diagnostics.single, contains('/no/such/setsid'));
      expect(diagnostics.single, contains('/no/such/perl'));
    });
  });
}
