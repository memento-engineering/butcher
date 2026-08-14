import '../model/mutant.dart';
import 'coverage_provider.dart';

/// MVP default: every mutant counts as covered.
final class FullCoverageProvider implements CoverageProvider {
  /// Creates the provider; it holds no state.
  const FullCoverageProvider();

  @override
  bool isCovered(Mutant mutant) => true;
}
