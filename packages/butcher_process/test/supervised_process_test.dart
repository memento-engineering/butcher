@TestOn('posix')
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:butcher_process/butcher_process.dart';
import 'package:butcher_process/src/posix_interlock.dart';
import 'package:test/test.dart';

/// Whether [pid] is still listed by the OS.
Future<bool> isRunning(int pid) async {
  final listed = await Process.run('/bin/ps', ['-p', '$pid', '-o', 'pid=']);
  return '${listed.stdout}'.trim().isNotEmpty;
}

/// [stream] decoded and joined once it ends.
Future<String> collect(Stream<List<int>> stream) =>
    stream.transform(utf8.decoder).join();

void main() {
  test('a normal exit reports its code through the shim', () async {
    final process = await SupervisedProcess.start('/bin/sh', ['-c', 'exit 7']);

    expect(await process.wait(), 7);
  });

  test('the working directory survives the exec', () async {
    final directory = Directory.systemTemp.createTempSync('butcher_process');
    addTearDown(() => directory.deleteSync(recursive: true));

    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      'pwd',
    ], workingDirectory: directory.path);
    final reported = collect(process.output);

    expect(await process.wait(), 0);
    expect(
      (await reported).trim(),
      endsWith(directory.uri.pathSegments.where((s) => s.isNotEmpty).last),
    );
  });

  test('both output streams survive the exec', () async {
    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      'echo out; echo err 1>&2',
    ]);
    final output = collect(process.output);
    final errors = collect(process.errorOutput);

    expect(await process.wait(), 0);
    expect(await output, 'out\n');
    expect(await errors, 'err\n');
  });

  test('the started pid is the group the census records', () async {
    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      'echo up; sleep 120',
    ]);
    addTearDown(process.kill);
    // Drained before the group is read: the shim's own group call lands
    // between the start returning and the target running, so a read taken
    // any earlier races it.
    await process.output.transform(utf8.decoder).first;

    expect(PosixInterlock.processGroupOf(process.pid), process.pid);
  });

  test('a deadline returns null and leaves nothing alive', () async {
    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      r'sleep 120 & echo $!; wait',
    ]);
    final grandchild = int.parse(
      (await process.output
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first)
          .trim(),
    );

    expect(await process.wait(deadline: const Duration(seconds: 1)), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await isRunning(process.pid), isFalse);
    expect(await isRunning(grandchild), isFalse);
  });

  test('kill is safe to call twice', () async {
    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      'sleep 120',
    ]);

    await process.kill();
    await expectLater(process.kill(), completes);
    expect(await isRunning(process.pid), isFalse);
  });

  test('terminate-all reaps independently started processes', () async {
    final first = await SupervisedProcess.start('/bin/sh', ['-c', 'sleep 120']);
    final second = await SupervisedProcess.start('/bin/sh', [
      '-c',
      'sleep 120',
    ]);

    await terminateAllSupervisedProcesses();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await isRunning(first.pid), isFalse);
    expect(await isRunning(second.pid), isFalse);
  });
}
