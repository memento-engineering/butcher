import 'mutation.dart';

/// One mutated code variant tracked through a run.
class Mutant {
  /// Creates a mutant with a stable [id] for [mutation].
  const Mutant({required this.id, required this.mutation});

  /// Stable across runs: derived from file, node offset, and operator id.
  final String id;

  /// The source change this mutant carries.
  final Mutation mutation;
}
