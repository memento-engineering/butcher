@TestOn('windows')
@Timeout(Duration(minutes: 1))
library;

import 'dart:io';

import 'package:butcher_process/src/windows_interlock.dart';
import 'package:test/test.dart';

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

void main() {
  test('kills a started process and its children together', () async {
    final interlock = WindowsInterlock();

    // Started through the interlock, so it is admitted before this test can
    // drain a stream of it and the child joins the job with it.
    final parent = await interlock.start('powershell', [
      '-NoProfile',
      '-Command',
      'Start-Sleep -Seconds 1; '
          'Start-Process powershell -ArgumentList '
          "'-NoProfile','-Command','Start-Sleep -Seconds 120' -PassThru "
          '| Select-Object -ExpandProperty Id; '
          'Start-Sleep -Seconds 120',
    ]);
    final child = int.parse(
      (await parent.stdout.transform(const SystemEncoding().decoder).first)
          .trim(),
    );

    await interlock.terminate(parent);

    expect(await parent.exitCode, isNot(0));
    expect(
      await isRunning(child),
      isFalse,
      reason: 'the job kills what its members started, not just its members',
    );
    interlock.dispose();
  });

  test('reports failure to admit a process that is gone', () async {
    final interlock = WindowsInterlock();
    final short = await Process.start('powershell', [
      '-NoProfile',
      '-Command',
      'Start-Sleep -Seconds 120',
    ]);
    short.kill();
    await short.exitCode;

    expect(interlock.admit(short.pid), isFalse);
    interlock.dispose();
  });
}
