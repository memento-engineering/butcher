import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/test_run.dart';
import 'test_runner.dart';

/// Runs `dart test` via [Platform.resolvedExecutable] (ADR 0003).
final class DartTestRunner implements TestRunner {
  /// Creates a runner executing inside [root].
  ///
  /// [concurrency] caps the suite's own test concurrency so parallel
  /// workers share the cores instead of oversubscribing them (ADR 0017).
  const DartTestRunner(this.root, {this.concurrency});

  /// Package root the suite runs from.
  final String root;

  /// Value for `dart test --concurrency`; `null` keeps the suite default.
  final int? concurrency;

  @override
  Future<TestRun> run({
    List<String>? tests,
    Duration? timeout,
    bool failFast = false,
  }) async {
    final watch = Stopwatch()..start();
    // On Linux, setsid puts the suite in its own process group so a timeout
    // can kill the whole tree, matching taskkill /T on Windows. macOS ships
    // no setsid binary, so it keeps the single-process kill.
    final process = await Process.start(
      Platform.isLinux ? 'setsid' : Platform.resolvedExecutable,
      [
        if (Platform.isLinux) Platform.resolvedExecutable,
        'test',
        '--reporter',
        'json',
        if (failFast) '--fail-fast',
        if (concurrency != null) '--concurrency=$concurrency',
        for (final name in tests ?? const <String>[]) ...['--plain-name', name],
      ],
      workingDirectory: root,
    );

    const decoder = Utf8Decoder(allowMalformed: true);
    final output = StringBuffer();
    final errors = StringBuffer();
    final drained = Future.wait([
      process.stdout.transform(decoder).forEach(output.write),
      process.stderr.transform(decoder).forEach(errors.write),
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
      errorOutput: errors.toString(),
      duration: watch.elapsed,
    );
  }

  static Future<void> _killTree(Process process) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
    } else if (Platform.isLinux) {
      final kill = await Process.run('kill', ['-9', '--', '-${process.pid}']);
      if (kill.exitCode != 0) process.kill(ProcessSignal.sigkill);
    } else {
      process.kill(ProcessSignal.sigkill);
    }
    await process.exitCode;
  }
}
