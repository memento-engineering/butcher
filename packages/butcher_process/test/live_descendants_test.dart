@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:butcher_process/butcher_process.dart';
import 'package:test/test.dart';

/// How long the census is given to come back empty after a kill.
///
/// Reaping is asynchronous on both platforms; a leak is not, which is what
/// this window separates.
const _grace = Duration(seconds: 5);

/// The census once it is empty, or its last reading after [_grace].
Future<Set<int>> settledDescendants() async {
  final waited = Stopwatch()..start();
  var live = await liveDescendants();
  while (live.isNotEmpty && waited.elapsed < _grace) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    live = await liveDescendants();
  }
  return live;
}

/// The first [count] lines of [stream], read as pids while it keeps draining.
Future<List<int>> reportedPids(Stream<List<int>> stream, int count) {
  final pids = <int>[];
  final read = Completer<List<int>>();
  stream
      .transform(systemEncoding.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (read.isCompleted || line.trim().isEmpty) return;
        pids.add(int.parse(line.trim()));
        if (pids.length == count) read.complete(pids);
      });
  return read.future;
}

void main() {
  test('lists a child and its grandchildren by process group', () async {
    final process = await SupervisedProcess.start('/bin/sh', [
      '-c',
      r'sleep 120 & echo $!; sleep 120 & echo $!; wait',
    ]);
    addTearDown(process.kill);
    final grandchildren = await reportedPids(process.output, 2);

    expect(await liveDescendants(), {process.pid, ...grandchildren});

    await process.kill();

    expect(await settledDescendants(), isEmpty);
  }, testOn: 'posix');

  test('lists a child and its grandchildren through the job', () async {
    final process = await SupervisedProcess.start('powershell', [
      '-NoProfile',
      '-Command',
      'Start-Process powershell -ArgumentList '
          "'-NoProfile','-Command','Start-Sleep -Seconds 120' -PassThru "
          '| Select-Object -ExpandProperty Id; '
          'Start-Process powershell -ArgumentList '
          "'-NoProfile','-Command','Start-Sleep -Seconds 120' -PassThru "
          '| Select-Object -ExpandProperty Id; '
          'Start-Sleep -Seconds 120',
    ]);
    addTearDown(process.kill);
    final grandchildren = await reportedPids(process.output, 2);

    expect(
      await liveDescendants(),
      containsAll([process.pid, ...grandchildren]),
    );

    await process.kill();

    expect(await settledDescendants(), isEmpty);
  }, testOn: 'windows');
}
