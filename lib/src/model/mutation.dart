/// A single source change proposed by a mutagen.
///
/// Pure data: rewriting and execution live in the engine, never in mutagens.
class Mutation {
  const Mutation({
    required this.filePath,
    required this.offset,
    required this.length,
    required this.original,
    required this.replacement,
    required this.operatorId,
    required this.description,
  });

  final String filePath;
  final int offset;
  final int length;
  final String original;
  final String replacement;
  final String operatorId;
  final String description;
}
