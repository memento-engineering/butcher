@TestOn('windows')
@Timeout(Duration(minutes: 1))
library;

import 'dart:io';

import 'package:butcher/src/engine/process_interlock.dart';
import 'package:test/test.dart';

/// Starts a process that outlives the test unless something kills it.
Future<Process> longRunning() => Process.start('powershell', [
  '-NoProfile',
  '-Command',
  'Start-Sleep -Seconds 120',
]);

void main() {
  test('kills an admitted process and its children together', () async {
    final interlock = ProcessInterlock.create();
    expect(interlock, isNotNull, reason: 'windows has job objects');

    final parent = await Process.start('powershell', [
      '-NoProfile',
      '-Command',
      // Admitted before it spawns, so the child joins the job with it.
      'Start-Sleep -Seconds 1; '
          'Start-Process powershell -ArgumentList '
          "'-NoProfile','-Command','Start-Sleep -Seconds 120' -PassThru "
          '| Select-Object -ExpandProperty Id; '
          'Start-Sleep -Seconds 120',
    ]);
    expect(interlock!.admit(parent.pid), isTrue);
    final child = int.parse(
      (await parent.stdout.transform(const SystemEncoding().decoder).first)
          .trim(),
    );

    interlock.terminate();

    expect(await parent.exitCode, isNot(0));
    expect(
      await isRunning(child),
      isFalse,
      reason: 'the job kills what its members started, not just its members',
    );
    interlock.dispose();
  });

  test('reports failure to admit a process that is gone', () async {
    final interlock = ProcessInterlock.create()!;
    final short = await longRunning();
    short.kill();
    await short.exitCode;

    expect(interlock.admit(short.pid), isFalse);
    interlock.dispose();
  });
}

/// Whether [pid] is still listed by the OS.
Future<bool> isRunning(int pid) async {
  final listed = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    'Get-Process -Id $pid -ErrorAction SilentlyContinue | '
        'Select-Object -ExpandProperty Id',
  ]);
  return '${listed.stdout}'.trim() == '$pid';
}
