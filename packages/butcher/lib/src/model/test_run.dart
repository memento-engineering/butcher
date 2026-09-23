import 'test_events.dart';

/// Observable outcome of one test-suite process.
///
/// Equality is over the observable outcome alone — [exitCode], [timedOut],
/// [output], [errorOutput] and [duration] — and deliberately excludes
/// [events]: the events are a parsed view of [output] held in a mechanism
/// class with mutable accumulating state and no equality of its own, so two
/// runs that observed the same process are the same run whether or not a
/// runner handed the parse along.
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

  /// Whether the process exceeded its deadline and was killed.
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

  /// Value equality over the observable outcome; [events] is excluded because
  /// it is a parsed view of [output], as the class doc explains.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestRun &&
          exitCode == other.exitCode &&
          timedOut == other.timedOut &&
          output == other.output &&
          errorOutput == other.errorOutput &&
          duration == other.duration;

  /// Hashes the same five observable fields [operator ==] compares.
  @override
  int get hashCode =>
      Object.hash(exitCode, timedOut, output, errorOutput, duration);

  /// Names the exit code, the timed-out flag and the duration.
  @override
  String toString() =>
      'TestRun(exit $exitCode, timedOut: $timedOut, $duration)';
}
