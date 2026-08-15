/// A run-level failure that aborts before any mutant is classified.
///
/// Mutant-level failures are outcomes, never exceptions (ADR 0006); this
/// exception covers preconditions like a red background reading (ADR 0005).
final class RunAborted implements Exception {
  /// Creates an abort with a consumer-facing [message].
  const RunAborted(this.message);

  /// Why the run could not proceed.
  final String message;

  @override
  String toString() => 'RunAborted: $message';
}
