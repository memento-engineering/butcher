import 'package:path/path.dart' as p;

import '../model/test_run.dart';
import 'suite_process.dart';
import 'test_runner.dart';

/// Name of the merged report `flutter test` writes into a coverage
/// directory; it records no per-suite split.
const flutterLcovName = 'lcov.info';

/// Runs `flutter test` through the [flutter] command for a package that
/// depends on the Flutter SDK.
final class FlutterTestRunner implements TestRunner {
  /// Creates a runner executing inside [root]; [concurrency] caps the test
  /// processes the suite runs at once (ADR 0017).
  const FlutterTestRunner(this.root, {required this.flutter, this.concurrency});

  /// Package root the suite runs from.
  final String root;

  /// Path of the `flutter` command.
  final String flutter;

  /// Value for `flutter test --concurrency`; `null` keeps the suite default.
  final int? concurrency;

  @override
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  }) => runSuite(
    flutter,
    [
      'test',
      // The sandbox is resolved once; every run re-resolving it would only
      // add to the deadline.
      '--no-pub',
      '--reporter',
      'json',
      if (failFast) '--fail-fast',
      if (coverageDir != null) ...[
        '--coverage',
        '--coverage-path=${p.join(coverageDir, flutterLcovName)}',
      ],
      if (concurrency != null) '--concurrency=$concurrency',
      ...suites,
    ],
    root: root,
    timeout: timeout,
  );
}
