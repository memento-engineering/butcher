import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'test_run.dart';
import 'test_runner.dart';

/// Runs `dart test` via [Platform.resolvedExecutable] (ADR 0003).
final class DartTestRunner implements TestRunner {
  /// Creates a runner executing inside [root].
  const DartTestRunner(this.root);

  /// Package root the suite runs from.
  final String root;

  @override
  Future<TestRun> run({List<String>? tests, Duration? timeout}) async {
    final watch = Stopwatch()..start();
    final process = await Process.start(Platform.resolvedExecutable, [
      'test',
      for (final name in tests ?? const <String>[]) ...['--plain-name', name],
    ], workingDirectory: root);

    const decoder = Utf8Decoder(allowMalformed: true);
    final output = StringBuffer();
    final drained = Future.wait([
      process.stdout.transform(decoder).forEach(output.write),
      process.stderr.transform(decoder).forEach(output.write),
    ]);

    var exitCode = -1;
    var timedOut = false;
    try {
      exitCode = timeout == null
          ? await process.exitCode
          : await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      await _killTree(process);
    }
    await drained.timeout(const Duration(seconds: 5), onTimeout: () => []);

    return TestRun(
      exitCode: exitCode,
      timedOut: timedOut,
      output: output.toString(),
      duration: watch.elapsed,
    );
  }

  static Future<void> _killTree(Process process) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
    } else {
      process.kill(ProcessSignal.sigkill);
    }
    await process.exitCode;
  }
}
