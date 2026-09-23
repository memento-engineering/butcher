/// One test file of the project under test, with what it cost to run.
final class TestSuite {
  /// Creates a suite record; [path] is project-relative and posix-separated.
  const TestSuite({required this.path, required this.duration});

  /// Path of the test file, as `dart test` takes it.
  final String path;

  /// Wall-clock span the suite took when coverage was collected; the routing
  /// order and deadline derive from it (ADR 0011).
  final Duration duration;
}
