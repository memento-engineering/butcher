/// Observable outcome of one test-suite process.
final class TestRun {
  /// Creates a record of a finished (or killed) test process.
  const TestRun({
    required this.exitCode,
    required this.timedOut,
    required this.output,
    required this.duration,
  });

  /// Process exit code; `-1` when the run [timedOut].
  final int exitCode;

  /// Whether the process exceeded its half-life and was killed.
  final bool timedOut;

  /// Combined stdout and stderr.
  final String output;

  /// Wall-clock duration of the run.
  final Duration duration;
}
