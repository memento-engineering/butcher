import 'dart:io';

import '../model/test_run.dart';
import 'suite_process.dart';
import 'test_runner.dart';

/// Runs `dart test` via [Platform.resolvedExecutable] (ADR 0003).
final class DartTestRunner implements TestRunner {
  /// Creates a runner executing inside [root].
  ///
  /// [concurrency] caps the suite's own test concurrency so parallel
  /// workers share the cores instead of oversubscribing them (ADR 0017).
  ///
  /// [maxHeapMb] caps the old generation of the VM hosting the suite; its
  /// tests run in that VM's isolates, so a runaway mutant fails there.
  const DartTestRunner(this.root, {this.concurrency, this.maxHeapMb});

  /// Package root the suite runs from.
  final String root;

  /// Value for `dart test --concurrency`; `null` keeps the suite default.
  final int? concurrency;

  /// Heap cap in megabytes; `null` leaves the VM uncapped.
  final int? maxHeapMb;

  @override
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  }) => runSuite(
    Platform.resolvedExecutable,
    [
      // DART_VM_OPTIONS does not reach the VM `dart test` runs in; only a
      // flag before the command does.
      if (maxHeapMb != null) '--old_gen_heap_size=$maxHeapMb',
      'test',
      '--reporter',
      'json',
      if (failFast) '--fail-fast',
      if (coverageDir != null) '--coverage=$coverageDir',
      if (concurrency != null) '--concurrency=$concurrency',
      ...suites,
    ],
    root: root,
    timeout: timeout,
  );
}
