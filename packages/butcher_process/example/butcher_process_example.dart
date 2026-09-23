import 'dart:convert';

import 'package:butcher_process/butcher_process.dart';

/// Runs one command under supervision, bounded by a deadline, and proves the
/// host is back where it started afterwards.
Future<void> main() async {
  final before = await hostProcessCount();

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

  print('host processes: $before before, ${await hostProcessCount()} after');
}
