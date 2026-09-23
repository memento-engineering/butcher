import '../model/test_run.dart';

/// Runs a project's test suite; seam for other runners (`flutter test`).
abstract interface class TestRunner {
  /// Runs [suites] (empty = whole suite), killed after [timeout] if set.
  ///
  /// [suites] are project-relative test file paths, cheapest first; routing
  /// selects them from the coverage data (ADR 0011).
  ///
  /// [failFast] stops the suite at the first failure: one failing test
  /// already kills a mutant, so the rest is wasted work.
  ///
  /// [coverageDir] instruments the run and collects its line coverage there
  /// (ADR 0020).
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  });
}
