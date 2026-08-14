import 'mutation.dart';

/// One mutated code variant tracked through a run.
class Mutant {
  const Mutant({required this.id, required this.mutation});

  /// Stable across runs: derived from file, node offset, and operator id.
  final String id;

  final Mutation mutation;
}
