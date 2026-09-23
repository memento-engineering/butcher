import '../model/mutant_result.dart';

/// One observation published on a run's live event stream.
///
/// The stream is the progress view; the end-of-run `RunResult` stays the
/// ordered one. See `Engine.events`.
sealed class RunEvent {
  /// Allows the subtypes in this library to be const.
  const RunEvent();
}

/// The run has measured its green baseline and is about to classify mutants.
///
/// [baseline] and [deadline] are the same two timings the end-of-run result
/// carries, so a consumer renders the numbers the report will show.
final class RunStarted extends RunEvent {
  /// Creates the opening event of a run over [mutantCount] mutants.
  const RunStarted({
    required this.mutantCount,
    required this.baseline,
    required this.deadline,
  });

  /// How many mutants this run will classify.
  final int mutantCount;

  /// Duration of the green baseline suite run (ADR 0005).
  final Duration baseline;

  /// Per-mutant timeout derived from [baseline] (ADR 0006).
  final Duration deadline;

  /// Value equality over every field.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunStarted &&
          mutantCount == other.mutantCount &&
          baseline == other.baseline &&
          deadline == other.deadline;

  /// Hashes the same three fields [operator ==] compares.
  @override
  int get hashCode => Object.hash(mutantCount, baseline, deadline);

  /// Names the mutant count and both timings in milliseconds.
  @override
  String toString() =>
      'RunStarted($mutantCount mutants, baseline ${baseline.inMilliseconds} '
      'ms, deadline ${deadline.inMilliseconds} ms)';
}

/// One mutant has been classified.
final class MutantClassified extends RunEvent {
  /// Creates the event announcing [result].
  const MutantClassified(this.result);

  /// The classified result, identical to the one the report will carry.
  final MutantResult result;

  /// Value equality over the composed [MutantResult].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutantClassified && result == other.result;

  /// Hashes the single field [operator ==] compares.
  @override
  int get hashCode => result.hashCode;

  /// Names the mutant id and the outcome it earned.
  @override
  String toString() =>
      'MutantClassified(${result.mutant.id}, ${result.outcome.name})';
}

/// Every mutant has been classified and the run is returning its result.
final class RunCompleted extends RunEvent {
  /// Creates the closing event of a run.
  const RunCompleted();

  /// Value equality: the event carries nothing, so every instance is equal.
  @override
  bool operator ==(Object other) => other is RunCompleted;

  /// Constant hash, matching the field-free [operator ==].
  @override
  int get hashCode => (RunCompleted).hashCode;

  /// Names the event.
  @override
  String toString() => 'RunCompleted()';
}
