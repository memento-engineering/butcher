/// Observable outcome of one test-suite process.
final class TestRun {
  /// Creates a record of a finished (or killed) test process.
  const TestRun({
    required this.exitCode,
    required this.timedOut,
    required this.output,
    this.errorOutput = '',
    required this.duration,
  });

  /// Process exit code; `-1` when the run [timedOut].
  final int exitCode;

  /// Whether the process exceeded its half-life and was killed.
  final bool timedOut;

  /// Suite stdout: the JSON reporter event stream.
  final String output;

  /// Suite stderr, buffered separately so it cannot split an event line.
  final String errorOutput;

  /// Wall-clock duration of the run.
  final Duration duration;
}
