import '../model/mutant.dart';

/// Which mutants the test suite can reach at all.
///
/// Seam for the v1.0 tracer; the MVP default is [FullCoverageProvider] in
/// full_coverage_provider.dart.
abstract interface class CoverageProvider {
  bool isCovered(Mutant mutant);
}
