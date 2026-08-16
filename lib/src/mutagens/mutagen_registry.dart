import 'arithmetic_mutagen.dart';
import 'boolean_literal_mutagen.dart';
import 'equality_mutagen.dart';
import 'logical_mutagen.dart';
import 'mutagen.dart';
import 'null_aware_access_mutagen.dart';
import 'null_coalescing_mutagen.dart';
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
        NullCoalescingMutagen(),
        NullAwareAccessMutagen(),
      ];

  /// The registered mutagens.
  final List<Mutagen> mutagens;

  /// Registered mutagens of type [T].
  Iterable<T> ofType<T extends Mutagen>() => mutagens.whereType<T>();
}
