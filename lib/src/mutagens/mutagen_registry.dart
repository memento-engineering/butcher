import 'arithmetic_mutagen.dart';
import 'boolean_literal_mutagen.dart';
import 'equality_mutagen.dart';
import 'logical_mutagen.dart';
import 'mutagen.dart';
import 'relational_mutagen.dart';

/// The active set of mutagens for a run.
final class MutagenRegistry {
  /// Creates a registry over [mutagens].
  const MutagenRegistry(this.mutagens);

  /// Creates the default MVP operator set.
  MutagenRegistry.defaults()
    : mutagens = const [
        ArithmeticMutagen(),
        RelationalMutagen(),
        EqualityMutagen(),
        LogicalMutagen(),
        BooleanLiteralMutagen(),
      ];

  /// The registered mutagens.
  final List<Mutagen> mutagens;

  /// Registered mutagens of type [T].
  Iterable<T> ofType<T extends Mutagen>() => mutagens.whereType<T>();
}
