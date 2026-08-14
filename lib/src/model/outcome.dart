/// Result category for one mutant; every result is data, never an exception.
///
/// The full taxonomy exists from the MVP, even for outcomes only produced by
/// later stages.
enum Outcome {
  killed,
  survived,
  noCoverage,
  timeout,
  unviable,
  runError,
  memoryError,
  equivalent,
}
