/// A single source change proposed by a mutator.
///
/// Pure data: rewriting and execution live in the engine, never in mutators.
class Mutation {
  /// Creates a mutation replacing [original] with [replacement].
  const Mutation({
    required this.filePath,
    required this.offset,
    required this.length,
    required this.original,
    required this.replacement,
    required this.mutatorId,
    required this.description,
  });

  /// Path of the file this mutation applies to.
  final String filePath;

  /// Offset of the replaced range within [filePath].
  final int offset;

  /// Length of the replaced range.
  final int length;

  /// Source text being replaced.
  final String original;

  /// Source text the mutant substitutes.
  final String replacement;

  /// Id of the mutator that proposed this mutation.
  final String mutatorId;

  /// Human-readable summary shown in reports.
  final String description;
}
