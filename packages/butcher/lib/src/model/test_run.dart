import 'test_events.dart';

/// Observable outcome of one test-suite process.
final class TestRun {
  /// Creates a record of a finished (or killed) test process.
  const TestRun({
    required this.exitCode,
    required this.timedOut,
    required this.output,
    this.errorOutput = '',
    this.events,
    required this.duration,
  });

  /// Process exit code; `-1` when the run [timedOut].
  final int exitCode;

  /// Whether the process exceeded its half-life and was killed.
  final bool timedOut;

  /// Suite stdout: the JSON reporter event stream, capped while it is read
  /// (`CappedOutput`) so a runaway mutant cannot exhaust memory. Once the
  /// mutant is classified, only an excerpt of it is retained (ADR 0016).
  final String output;

  /// Suite stderr, buffered separately so it cannot split an event line,
  /// and capped tighter than [output] since nothing is parsed from it.
  final String errorOutput;

  /// Reporter events parsed from the live stream before [output] was capped.
  /// Custom runners may omit them; the engine then parses [output].
  final TestEvents? events;

  /// Wall-clock duration of the run.
  final Duration duration;
}
