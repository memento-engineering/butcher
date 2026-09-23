import 'mutation.dart';

/// One mutated code variant tracked through a run.
class Mutant {
  /// Creates a mutant with a stable [id] for [mutation].
  const Mutant({required this.id, required this.mutation});

  /// Stable across runs: derived from file, node offset, and operator id.
  final String id;

  /// The source change this mutant carries.
  final Mutation mutation;

  /// Value equality over [id] and [mutation], composing the mutation's own.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Mutant && id == other.id && mutation == other.mutation;

  /// Hashes the same two fields [operator ==] compares.
  @override
  int get hashCode => Object.hash(id, mutation);

  /// Names the mutant id.
  @override
  String toString() => 'Mutant($id)';
}
