import 'dart:convert';
import 'dart:io';

import 'package:butcher_process/butcher_process.dart';

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
    // The suite is a kill boundary from the moment it exists, so what it
    // spawns afterwards dies with it in one call (ADR 0022).
    final process = await SupervisedProcess.start(Platform.resolvedExecutable, [
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
      process.output.transform(decoder).forEach((chunk) {
        events.add(chunk);
        output.write(chunk);
      }),
      process.errorOutput.transform(decoder).forEach(errors.write),
    ]);

    final code = await process.wait(deadline: timeout);
    await drained.timeout(const Duration(seconds: 5), onTimeout: () => []);
    events.close();

    return TestRun(
      // A deadline leaves no exit code to report; the classifier reads the
      // timeout marker instead.
      exitCode: code ?? -1,
      timedOut: code == null,
      output: output.toString(),
      errorOutput: errors.toString(),
      events: events,
      duration: watch.elapsed,
    );
  }
}
