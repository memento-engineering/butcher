import '../model/mutant.dart';
import '../model/test_suite.dart';
import 'coverage_provider.dart';

/// MVP default: every mutant counts as covered.
final class FullCoverageProvider implements CoverageProvider {
  /// Creates the provider; it holds no state.
  const FullCoverageProvider();

  @override
  bool isCovered(Mutant mutant) => true;

  @override
  List<TestSuite>? suitesFor(Mutant mutant) => null;

  @override
  void indexSources(Map<String, String> sources) {}
}
