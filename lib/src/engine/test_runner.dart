import '../model/test_run.dart';

/// Runs a project's test suite; seam for other runners (`flutter test`).
abstract interface class TestRunner {
  /// Runs [tests] (`null` = whole suite), killed after [timeout] if set.
  ///
  /// [failFast] stops the suite at the first failure: one failing test
  /// already kills a mutant, so the rest is wasted work.
  Future<TestRun> run({
    List<String>? tests,
    Duration? timeout,
    bool failFast = false,
  });
}
