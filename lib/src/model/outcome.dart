/// Result category for one mutant; every result is data, never an exception.
///
/// The full taxonomy exists from the MVP, even for outcomes only produced by
/// later stages.
enum Outcome {
  /// A test failed while the mutant was active.
  killed,

  /// Every selected test passed; the mutant escaped.
  survived,

  /// No test covers the mutation site.
  noCoverage,

  /// The test run exceeded the mutant's half-life.
  timeout,

  /// The mutant does not compile.
  unviable,

  /// The test process failed for a reason other than a failing test.
  runError,

  /// The test process ran out of memory.
  memoryError,

  /// The mutant is behaviorally identical to the original code.
  equivalent,
}
