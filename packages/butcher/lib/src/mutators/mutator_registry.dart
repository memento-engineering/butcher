import 'arithmetic_mutator.dart';
import 'boolean_literal_mutator.dart';
import 'equality_mutator.dart';
import 'logical_mutator.dart';
import 'mutator.dart';
import 'null_aware_access_mutator.dart';
import 'null_coalescing_mutator.dart';
import 'null_injection_mutator.dart';
import 'relational_mutator.dart';

/// The active set of mutators for a run.
final class MutatorRegistry {
  /// Creates a registry over [mutators].
  const MutatorRegistry(this.mutators);

  /// Creates the default MVP operator set.
  MutatorRegistry.defaults()
    : mutators = const [
        ArithmeticMutator(),
        RelationalMutator(),
        EqualityMutator(),
        LogicalMutator(),
        BooleanLiteralMutator(),
        NullCoalescingMutator(),
        NullAwareAccessMutator(),
        NullInjectionMutator(),
      ];

  /// The registered mutators.
  final List<Mutator> mutators;

  /// Registered mutators of type [T].
  Iterable<T> ofType<T extends Mutator>() => mutators.whereType<T>();
}
