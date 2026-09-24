import 'dart:convert';

import 'package:butcher_process/butcher_process.dart';

/// Runs one command under supervision, bounded by a deadline, and proves the
/// run left nothing of its own behind.
Future<void> main() async {
  final process = await SupervisedProcess.start('dart', ['--version']);
  print('started pid ${process.pid}');

  process.errorOutput
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(print);

  final code = await process.wait(deadline: const Duration(minutes: 1));
  if (code == null) {
    print('the tree was killed on its deadline');
  } else {
    print('exited with $code');
  }

  // A signal handler needs no handle on whatever pool started the work: this
  // reaps every tree that is still live.
  await terminateAllSupervisedProcesses();

  // Run-scoped, so it says what this run leaked rather than what the host was
  // busy with; the whole-host count is a diagnostic beside it.
  print('still running from this run: ${await liveDescendants()}');
  print('host processes: ${await hostProcessCount()}');
}
