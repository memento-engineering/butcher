import 'test_run.dart';

/// Runs a project's test suite; seam for other runners (`flutter test`).
abstract interface class TestRunner {
  /// Runs [tests] (`null` = whole suite), killed after [timeout] if set.
  Future<TestRun> run({List<String>? tests, Duration? timeout});
}
