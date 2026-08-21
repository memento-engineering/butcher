import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/test_events.dart';
import '../model/test_run.dart';
import 'capped_output.dart';
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

  /// Characters retained from stdout. Every verdict is parsed out of this
  /// stream, so the bound sits above any real suite (~16k tests' events) and
  /// only catches a runaway mutant.
  static const stdoutLimit = 8 * 1024 * 1024;

  /// Characters retained from stderr; nothing is parsed from it.
  static const stderrLimit = 256 * 1024;

  @override
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  }) async {
    final watch = Stopwatch()..start();
    final process = await Process.start(Platform.resolvedExecutable, [
      'test',
      '--reporter',
      'json',
      if (failFast) '--fail-fast',
      if (coverageDir != null) '--coverage=$coverageDir',
      if (concurrency != null) '--concurrency=$concurrency',
      ...suites,
    ], workingDirectory: root);

    const decoder = Utf8Decoder(allowMalformed: true);
    final output = CappedOutput(limit: stdoutLimit);
    final errors = CappedOutput(limit: stderrLimit);
    final events = TestEvents();
    final drained = Future.wait([
      process.stdout.transform(decoder).forEach((chunk) {
        events.add(chunk);
        output.write(chunk);
      }),
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
    events.close();

    return TestRun(
      exitCode: exitCode,
      timedOut: timedOut,
      output: output.toString(),
      errorOutput: errors.toString(),
      events: events,
      duration: watch.elapsed,
    );
  }

  /// Kills the suite and everything it spawned. Windows walks the tree with
  /// `taskkill /T`; elsewhere the tree comes from a `ps` snapshot taken
  /// before the kill, while the children are still attached, so processes
  /// spawned after it survive.
  static Future<void> _killTree(Process process) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
    } else {
      final pids = descendantPids(await processSnapshot(), process.pid);
      process.kill(ProcessSignal.sigkill);
      for (final pid in pids) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
    }
    await process.exitCode;
  }

  /// `ps -A -o pid=,ppid=` output, or empty when the image has no [ps]: a
  /// missing helper costs the descendants, never the hung suite itself.
  ///
  /// [ps] is a seam for tests to cover the missing case on any platform.
  static Future<String> processSnapshot([String ps = 'ps']) async {
    try {
      return '${(await Process.run(ps, ['-A', '-o', 'pid=,ppid='])).stdout}';
    } on ProcessException {
      return '';
    }
  }

  /// Transitive child pids of [rootPid] in `ps -A -o pid=,ppid=` output.
  ///
  /// Public so tests can cover it on any platform.
  static List<int> descendantPids(String psOutput, int rootPid) {
    final childrenOf = <int, List<int>>{};
    for (final line in const LineSplitter().convert(psOutput)) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 2) continue;
      final pid = int.tryParse(fields[0]);
      final ppid = int.tryParse(fields[1]);
      if (pid == null || ppid == null) continue;
      childrenOf.putIfAbsent(ppid, () => []).add(pid);
    }
    final seen = <int>{};
    final queue = [rootPid];
    while (queue.isNotEmpty) {
      for (final child in childrenOf[queue.removeLast()] ?? const <int>[]) {
        if (seen.add(child)) queue.add(child);
      }
    }
    return seen.toList();
  }
}
