import '../model/test_run.dart';
import 'test_runner.dart';

/// Runs [tests] wherever [inner] would run the whole suite, so a package
/// that bundles its test files into one entry pays one startup per run.
final class NamedTestsRunner implements TestRunner {
  /// Wraps [inner], substituting [tests] for an empty suite selection.
  const NamedTestsRunner(this.inner, this.tests);

  /// The runner that executes the suite.
  final TestRunner inner;

  /// Project-relative test files standing in for the whole suite.
  final List<String> tests;

  @override
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  }) => inner.run(
    suites: suites.isEmpty ? tests : suites,
    timeout: timeout,
    failFast: failFast,
    coverageDir: coverageDir,
  );
}
